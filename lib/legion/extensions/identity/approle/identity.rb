# frozen_string_literal: true

module Legion
  module Extensions
    module Identity
      module Approle
        module Identity
          module_function

          def provider_name
            :approle
          end

          def provider_type
            :auth
          end

          def facing
            :machine
          end

          def priority
            100
          end

          def trust_weight
            100
          end

          def capabilities
            %i[authenticate vault_auth]
          end

          def resolve(canonical_name: nil) # rubocop:disable Lint/UnusedMethodArgument
            return nil unless role_id && secret_id

            lease = provide_token
            return nil unless lease

            meta = lease.metadata || {}
            {
              canonical_name: normalize(meta[:role_name] || "approle-#{role_id[0..7]}"),
              kind:           :machine,
              source:         :approle,
              persistent:     true,
              groups:         meta[:policies] || [],
              metadata:       { role_name: meta[:role_name], policies: meta[:policies] }
            }
          end

          def provide_token
            return @cached_lease if @cached_lease&.valid? # rubocop:disable ThreadSafety/ClassInstanceVariable
            return nil unless role_id && secret_id

            response = vault_approle_login(role_id: role_id, secret_id: secret_id)
            return nil unless response

            @cached_lease = build_lease(response) # rubocop:disable ThreadSafety/ClassInstanceVariable
          end

          def normalize(val)
            val.to_s.downcase.strip.gsub(/[^a-z0-9_-]/, '_')
          end

          def build_lease(response)
            Legion::Identity::Lease.new(
              provider:   :approle,
              credential: response.auth.client_token,
              lease_id:   response.auth.lease_id,
              expires_at: Time.now + response.auth.lease_duration,
              renewable:  response.auth.renewable,
              issued_at:  Time.now,
              metadata:   { policies: response.auth.policies }
            )
          end

          def vault_approle_login(role_id:, secret_id:)
            logical = if defined?(Legion::Crypt::LeaseManager)
                        Legion::Crypt::LeaseManager.instance.logical
                      else
                        ::Vault.logical
                      end
            logical.write(
              "auth/#{settings[:auth_path] || 'approle'}/login",
              role_id:   role_id,
              secret_id: secret_id
            )
          rescue ::Vault::HTTPError => e
            Legion::Logging.warn("AppRole login failed: #{e.message}") if defined?(Legion::Logging) # rubocop:disable Legion/HelperMigration/DirectLogging, Legion/HelperMigration/LoggingGuard
            nil
          end

          def role_id
            settings[:role_id] || read_file(settings[:role_id_file])
          end

          def secret_id
            settings[:secret_id] || read_file(settings[:secret_id_file])
          end

          def read_file(path)
            return nil unless path && File.exist?(path)

            File.read(path).strip
          end

          def settings
            Approle::Settings.settings
          end

          private_class_method :build_lease, :vault_approle_login, :role_id, :secret_id, :read_file, :settings
        end
      end
    end
  end
end
