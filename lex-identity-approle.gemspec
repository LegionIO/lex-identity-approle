# frozen_string_literal: true

require_relative 'lib/legion/extensions/identity/approle/version'

Gem::Specification.new do |spec|
  spec.name          = 'lex-identity-approle'
  spec.version       = Legion::Extensions::Identity::Approle::VERSION
  spec.authors       = ['Esity']
  spec.email         = ['matthewdiverson@gmail.com']

  spec.summary       = 'LEX Identity AppRole'
  spec.description   = 'LegionIO Vault AppRole identity provider — machine identity for headless services authenticating to Vault'
  spec.homepage      = 'https://github.com/LegionIO/lex-identity-approle'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.4'

  spec.metadata['homepage_uri']          = spec.homepage
  spec.metadata['source_code_uri']       = 'https://github.com/LegionIO/lex-identity-approle'
  spec.metadata['documentation_uri']     = 'https://github.com/LegionIO/lex-identity-approle'
  spec.metadata['changelog_uri']         = 'https://github.com/LegionIO/lex-identity-approle'
  spec.metadata['bug_tracker_uri']       = 'https://github.com/LegionIO/lex-identity-approle/issues'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.require_paths = ['lib']

  spec.add_dependency 'legion-json',     '>= 1.2.1'
  spec.add_dependency 'legion-settings', '>= 1.3.14'
end
