# frozen_string_literal: true

require 'legion/extensions/identity/approle/version'
require 'legion/extensions/identity/approle/settings'
require 'legion/extensions/identity/approle/identity'

module Legion
  module Extensions
    module Identity
      module Approle
        extend Legion::Extensions::Core if Legion::Extensions.const_defined?(:Core, false)

        def self.identity_provider?
          true
        end

        def self.remote_invocable?
          false
        end

        def self.provider_name
          Identity.provider_name
        end

        def self.provider_type
          Identity.provider_type
        end

        def self.facing
          Identity.facing
        end
      end
    end
  end
end
