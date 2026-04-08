# frozen_string_literal: true

require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
end

require 'bundler/setup'
require 'fileutils'
require 'tmpdir'

module Legion
  module Extensions
    module Helpers
      module Lex; end
    end
  end

  module Logging
    def self.warn(msg); end
    def self.info(msg); end
    def self.debug(msg); end
  end

  module Settings
    def self.[](_key)
      nil
    end

    def self.dig(*_keys)
      nil
    end

    def self.merge_settings(_key, _defaults); end
  end

  module JSON
    def self.dump(obj)
      require 'json'
      ::JSON.generate(obj)
    end

    def self.load(str)
      require 'json'
      ::JSON.parse(str, symbolize_names: true)
    end
  end

  module Identity
    class Lease
      attr_reader :provider, :credential, :lease_id, :expires_at, :renewable, :issued_at, :metadata

      def initialize(provider:, credential:, expires_at:, renewable:, issued_at:, lease_id: nil, metadata: {})
        @provider   = provider
        @credential = credential
        @lease_id   = lease_id
        @expires_at = expires_at
        @renewable  = renewable
        @issued_at  = issued_at
        @metadata   = metadata
      end

      def valid?
        return false unless @expires_at

        Time.now < @expires_at
      end
    end
  end
end

require 'legion/extensions/identity/approle'

RSpec.configure do |config|
  config.example_status_persistence_file_path = '.rspec_status'
  config.disable_monkey_patching!
  config.expect_with(:rspec) { |c| c.syntax = :expect }
end
