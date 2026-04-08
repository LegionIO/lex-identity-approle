# frozen_string_literal: true

module Legion
  module Extensions
    module Identity
      module Approle
        module Settings
          DEFAULTS = {
            role_id:        ENV.fetch('VAULT_APPROLE_ROLE_ID', nil),
            secret_id:      ENV.fetch('VAULT_APPROLE_SECRET_ID', nil),
            role_id_file:   '/run/secrets/vault-role-id',
            secret_id_file: '/run/secrets/vault-secret-id',
            auth_path:      'approle'
          }.freeze

          def self.settings
            return Legion::Settings[:identity][:approle] if defined?(Legion::Settings) &&
                                                            Legion::Settings[:identity].is_a?(Hash) &&
                                                            Legion::Settings[:identity][:approle].is_a?(Hash)

            DEFAULTS
          end
        end
      end
    end
  end
end
