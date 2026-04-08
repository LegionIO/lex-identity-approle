# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Identity::Approle::Settings do
  subject(:settings_module) { described_class }

  describe '.settings' do
    context 'when Legion::Settings is not configured (test environment)' do
      it 'returns a Hash' do
        expect(settings_module.settings).to be_a(Hash)
      end

      it 'includes :auth_path defaulting to approle' do
        expect(settings_module.settings[:auth_path]).to eq('approle')
      end

      it 'includes :role_id_file with default K8s path' do
        expect(settings_module.settings[:role_id_file]).to eq('/run/secrets/vault-role-id')
      end

      it 'includes :secret_id_file with default K8s path' do
        expect(settings_module.settings[:secret_id_file]).to eq('/run/secrets/vault-secret-id')
      end

      it 'has :role_id key' do
        expect(settings_module.settings).to have_key(:role_id)
      end

      it 'has :secret_id key' do
        expect(settings_module.settings).to have_key(:secret_id)
      end
    end

    context 'when Legion::Settings returns a configured approle section' do
      before do
        allow(Legion::Settings).to receive(:[]).with(:identity).and_return(
          approle: {
            role_id:        'configured-role-id',
            secret_id:      'configured-secret-id',
            role_id_file:   '/custom/role-id',
            secret_id_file: '/custom/secret-id',
            auth_path:      'custom-approle'
          }
        )
      end

      it 'returns the configured settings' do
        expect(settings_module.settings[:auth_path]).to eq('custom-approle')
      end

      it 'returns the configured role_id' do
        expect(settings_module.settings[:role_id]).to eq('configured-role-id')
      end
    end
  end

  describe 'DEFAULTS constant' do
    it 'is frozen' do
      expect(described_class::DEFAULTS).to be_frozen
    end

    it 'defaults auth_path to approle' do
      expect(described_class::DEFAULTS[:auth_path]).to eq('approle')
    end

    it 'defaults role_id_file to K8s secret mount' do
      expect(described_class::DEFAULTS[:role_id_file]).to eq('/run/secrets/vault-role-id')
    end

    it 'defaults secret_id_file to K8s secret mount' do
      expect(described_class::DEFAULTS[:secret_id_file]).to eq('/run/secrets/vault-secret-id')
    end
  end
end
