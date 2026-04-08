# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Identity::Approle::Identity do
  subject(:identity) { described_class }

  # Reset cached lease between examples
  before do
    described_class.instance_variable_set(:@cached_lease, nil)
  end

  # --- provider contract ---

  describe '.provider_name' do
    it 'returns :approle' do
      expect(identity.provider_name).to eq(:approle)
    end
  end

  describe '.provider_type' do
    it 'returns :auth' do
      expect(identity.provider_type).to eq(:auth)
    end

    it 'is not :fallback' do
      expect(identity.provider_type).not_to eq(:fallback)
    end

    it 'is not :profile' do
      expect(identity.provider_type).not_to eq(:profile)
    end
  end

  describe '.facing' do
    it 'returns :machine' do
      expect(identity.facing).to eq(:machine)
    end
  end

  describe '.priority' do
    it 'returns 100 (highest)' do
      expect(identity.priority).to eq(100)
    end
  end

  describe '.trust_weight' do
    it 'returns 100' do
      expect(identity.trust_weight).to eq(100)
    end
  end

  describe '.capabilities' do
    it 'includes :authenticate' do
      expect(identity.capabilities).to include(:authenticate)
    end

    it 'includes :vault_auth' do
      expect(identity.capabilities).to include(:vault_auth)
    end

    it 'does not include :profile' do
      expect(identity.capabilities).not_to include(:profile)
    end

    it 'does not include :groups' do
      expect(identity.capabilities).not_to include(:groups)
    end
  end

  # --- settings ---

  describe '.settings (via Settings module)' do
    it 'returns a hash with required keys' do
      settings = Legion::Extensions::Identity::Approle::Settings.settings
      expect(settings).to be_a(Hash)
      expect(settings).to have_key(:auth_path)
      expect(settings).to have_key(:role_id_file)
      expect(settings).to have_key(:secret_id_file)
    end

    it 'defaults auth_path to approle' do
      settings = Legion::Extensions::Identity::Approle::Settings.settings
      expect(settings[:auth_path]).to eq('approle')
    end
  end

  # --- normalize ---

  describe '.normalize' do
    it 'lowercases the value' do
      expect(identity.normalize('APPROLE')).to eq('approle')
    end

    it 'strips leading and trailing whitespace' do
      expect(identity.normalize('  svc  ')).to eq('svc')
    end

    it 'replaces dots with underscores' do
      expect(identity.normalize('vault.approle')).to eq('vault_approle')
    end

    it 'replaces @ with underscores' do
      expect(identity.normalize('svc@realm')).to eq('svc_realm')
    end

    it 'replaces other special characters with underscores' do
      expect(identity.normalize('svc#role!')).to eq('svc_role_')
    end

    it 'preserves underscores' do
      expect(identity.normalize('service_account')).to eq('service_account')
    end

    it 'preserves hyphens' do
      expect(identity.normalize('my-role')).to eq('my-role')
    end

    it 'preserves digits' do
      expect(identity.normalize('role42')).to eq('role42')
    end

    it 'handles an empty string' do
      expect(identity.normalize('')).to eq('')
    end

    it 'handles nil by converting to empty string' do
      expect(identity.normalize(nil)).to eq('')
    end
  end

  # --- provide_token ---

  describe '.provide_token' do
    context 'when role_id and secret_id are not configured' do
      before do
        allow(Legion::Extensions::Identity::Approle::Settings).to receive(:settings).and_return(
          role_id: nil, secret_id: nil,
          role_id_file: '/nonexistent/role-id',
          secret_id_file: '/nonexistent/secret-id',
          auth_path: 'approle'
        )
      end

      it 'returns nil' do
        expect(identity.provide_token).to be_nil
      end
    end

    context 'when role_id and secret_id are configured but vault login fails' do
      let(:settings_hash) do
        { role_id: 'test-role-id', secret_id: 'test-secret-id', auth_path: 'approle',
          role_id_file: nil, secret_id_file: nil }
      end

      before do
        allow(Legion::Extensions::Identity::Approle::Settings).to receive(:settings).and_return(settings_hash)
        stub_const('Vault', Module.new)
        vault_logical = double('VaultLogical')
        vault_http_error_class = Class.new(StandardError)
        stub_const('Vault::HTTPError', vault_http_error_class)
        allow(Vault).to receive(:logical).and_return(vault_logical)
        allow(vault_logical).to receive(:write).and_raise(Vault::HTTPError, 'permission denied')
      end

      it 'returns nil on vault error' do
        expect(identity.provide_token).to be_nil
      end
    end

    context 'when vault login succeeds' do
      let(:settings_hash) do
        { role_id: 'test-role-id', secret_id: 'test-secret-id', auth_path: 'approle',
          role_id_file: nil, secret_id_file: nil }
      end
      let(:vault_auth_response) do
        double(
          auth: double(
            client_token:   'hvs.testtoken',
            lease_id:       '',
            lease_duration: 3600,
            renewable:      true,
            policies:       %w[default legionio]
          )
        )
      end

      before do
        allow(Legion::Extensions::Identity::Approle::Settings).to receive(:settings).and_return(settings_hash)
        stub_const('Vault', Module.new)
        stub_const('Vault::HTTPError', Class.new(StandardError))
        vault_logical = double('VaultLogical')
        allow(Vault).to receive(:logical).and_return(vault_logical)
        allow(vault_logical).to receive(:write).and_return(vault_auth_response)
      end

      it 'returns a Lease object' do
        expect(identity.provide_token).to be_a(Legion::Identity::Lease)
      end

      it 'sets the provider to :approle' do
        expect(identity.provide_token.provider).to eq(:approle)
      end

      it 'sets the credential to the client token' do
        expect(identity.provide_token.credential).to eq('hvs.testtoken')
      end

      it 'sets issued_at to a recent Time' do
        lease = identity.provide_token
        expect(lease.issued_at).to be_a(Time)
        expect(lease.issued_at).to be_within(2).of(Time.now)
      end

      it 'sets expires_at in the future' do
        lease = identity.provide_token
        expect(lease.expires_at).to be > Time.now
      end

      it 'sets renewable from the vault response' do
        expect(identity.provide_token.renewable).to be true
      end

      it 'stores policies in metadata' do
        expect(identity.provide_token.metadata[:policies]).to eq(%w[default legionio])
      end
    end

    context 'when a valid cached lease exists' do
      let(:settings_hash) do
        { role_id: 'test-role-id', secret_id: 'test-secret-id', auth_path: 'approle',
          role_id_file: nil, secret_id_file: nil }
      end
      let(:cached) do
        Legion::Identity::Lease.new(
          provider:   :approle,
          credential: 'hvs.cached',
          expires_at: Time.now + 3600,
          renewable:  true,
          issued_at:  Time.now,
          metadata:   { policies: ['default'] }
        )
      end

      before do
        allow(Legion::Extensions::Identity::Approle::Settings).to receive(:settings).and_return(settings_hash)
        described_class.instance_variable_set(:@cached_lease, cached)
      end

      it 'returns the cached lease without calling vault' do
        expect(identity.provide_token).to eq(cached)
      end
    end

    context 'when the cached lease is expired' do
      let(:settings_hash) do
        { role_id: 'test-role-id', secret_id: 'test-secret-id', auth_path: 'approle',
          role_id_file: nil, secret_id_file: nil }
      end
      let(:expired_lease) do
        Legion::Identity::Lease.new(
          provider:   :approle,
          credential: 'hvs.expired',
          expires_at: Time.now - 60,
          renewable:  false,
          issued_at:  Time.now - 3660,
          metadata:   {}
        )
      end
      let(:vault_auth_response) do
        double(
          auth: double(
            client_token:   'hvs.fresh',
            lease_id:       '',
            lease_duration: 3600,
            renewable:      true,
            policies:       ['default']
          )
        )
      end

      before do
        allow(Legion::Extensions::Identity::Approle::Settings).to receive(:settings).and_return(settings_hash)
        described_class.instance_variable_set(:@cached_lease, expired_lease)
        stub_const('Vault', Module.new)
        stub_const('Vault::HTTPError', Class.new(StandardError))
        vault_logical = double('VaultLogical')
        allow(Vault).to receive(:logical).and_return(vault_logical)
        allow(vault_logical).to receive(:write).and_return(vault_auth_response)
      end

      it 'fetches a new lease' do
        expect(identity.provide_token.credential).to eq('hvs.fresh')
      end
    end
  end

  # --- resolve ---

  describe '.resolve' do
    context 'when role_id and secret_id are not configured' do
      before do
        allow(Legion::Extensions::Identity::Approle::Settings).to receive(:settings).and_return(
          role_id: nil, secret_id: nil,
          role_id_file: '/nonexistent/role-id',
          secret_id_file: '/nonexistent/secret-id',
          auth_path: 'approle'
        )
      end

      it 'returns nil' do
        expect(identity.resolve).to be_nil
      end
    end

    context 'when provide_token returns nil' do
      let(:settings_hash) do
        { role_id: 'test-role-id', secret_id: 'test-secret-id', auth_path: 'approle',
          role_id_file: nil, secret_id_file: nil }
      end

      before do
        allow(Legion::Extensions::Identity::Approle::Settings).to receive(:settings).and_return(settings_hash)
        stub_const('Vault', Module.new)
        stub_const('Vault::HTTPError', Class.new(StandardError))
        vault_logical = double('VaultLogical')
        allow(Vault).to receive(:logical).and_return(vault_logical)
        allow(vault_logical).to receive(:write).and_raise(Vault::HTTPError, 'bad credentials')
      end

      it 'returns nil' do
        expect(identity.resolve).to be_nil
      end
    end

    context 'when vault login succeeds' do
      let(:settings_hash) do
        { role_id: 'test-role-id', secret_id: 'test-secret-id', auth_path: 'approle',
          role_id_file: nil, secret_id_file: nil }
      end
      let(:vault_auth_response) do
        double(
          auth: double(
            client_token:   'hvs.testtoken',
            lease_id:       '',
            lease_duration: 3600,
            renewable:      true,
            policies:       %w[default legionio]
          )
        )
      end

      before do
        allow(Legion::Extensions::Identity::Approle::Settings).to receive(:settings).and_return(settings_hash)
        stub_const('Vault', Module.new)
        stub_const('Vault::HTTPError', Class.new(StandardError))
        vault_logical = double('VaultLogical')
        allow(Vault).to receive(:logical).and_return(vault_logical)
        allow(vault_logical).to receive(:write).and_return(vault_auth_response)
      end

      it 'returns a hash' do
        expect(identity.resolve).to be_a(Hash)
      end

      it 'sets kind to :machine' do
        expect(identity.resolve[:kind]).to eq(:machine)
      end

      it 'sets source to :approle' do
        expect(identity.resolve[:source]).to eq(:approle)
      end

      it 'sets persistent to true' do
        expect(identity.resolve[:persistent]).to be true
      end

      it 'sets canonical_name from the role_id prefix when no role_name in metadata' do
        expect(identity.resolve[:canonical_name]).to eq('approle-test-rol')
      end

      it 'sets groups from the policies' do
        expect(identity.resolve[:groups]).to eq(%w[default legionio])
      end

      it 'includes metadata with policies' do
        expect(identity.resolve[:metadata][:policies]).to eq(%w[default legionio])
      end

      it 'reuses the cached lease after first resolve (does not call vault a second time)' do
        # First resolve populates the cache
        identity.resolve
        # Subsequent resolve should hit the cache
        vault_logical2 = double('VaultLogical2')
        allow(Vault).to receive(:logical).and_return(vault_logical2)
        expect(vault_logical2).not_to receive(:write)
        identity.resolve
      end
    end

    context 'when metadata includes a role_name' do
      let(:settings_hash) do
        { role_id: 'test-role-id', secret_id: 'test-secret-id', auth_path: 'approle',
          role_id_file: nil, secret_id_file: nil }
      end
      let(:vault_auth_response) do
        double(
          auth: double(
            client_token:   'hvs.testtoken',
            lease_id:       '',
            lease_duration: 3600,
            renewable:      true,
            policies:       ['default']
          )
        )
      end
      let(:lease_with_role_name) do
        Legion::Identity::Lease.new(
          provider:   :approle,
          credential: 'hvs.testtoken',
          expires_at: Time.now + 3600,
          renewable:  true,
          issued_at:  Time.now,
          metadata:   { role_name: 'legion-worker', policies: ['default'] }
        )
      end

      before do
        allow(Legion::Extensions::Identity::Approle::Settings).to receive(:settings).and_return(settings_hash)
        described_class.instance_variable_set(:@cached_lease, lease_with_role_name)
      end

      it 'uses the role_name for canonical_name' do
        expect(identity.resolve[:canonical_name]).to eq('legion-worker')
      end
    end
  end

  # --- top-level module contract ---

  describe 'Legion::Extensions::Identity::Approle (top-level module)' do
    subject(:mod) { Legion::Extensions::Identity::Approle }

    it 'declares itself as an identity provider' do
      expect(mod.identity_provider?).to be true
    end

    it 'is not remote invocable' do
      expect(mod.remote_invocable?).to be false
    end

    it 'delegates provider_name to Identity' do
      expect(mod.provider_name).to eq(:approle)
    end

    it 'delegates provider_type to Identity' do
      expect(mod.provider_type).to eq(:auth)
    end

    it 'delegates facing to Identity' do
      expect(mod.facing).to eq(:machine)
    end
  end

  # --- file-based credential loading ---

  describe 'file-based credential loading' do
    let(:tmpdir) { Dir.mktmpdir }
    let(:role_id_path)   { File.join(tmpdir, 'vault-role-id') }
    let(:secret_id_path) { File.join(tmpdir, 'vault-secret-id') }

    after { FileUtils.rm_rf(tmpdir) }

    before do
      File.write(role_id_path, "file-role-id\n")
      File.write(secret_id_path, "file-secret-id\n")
      allow(Legion::Extensions::Identity::Approle::Settings).to receive(:settings).and_return(
        role_id: nil, secret_id: nil,
        role_id_file:   role_id_path,
        secret_id_file: secret_id_path,
        auth_path: 'approle'
      )
      stub_const('Vault', Module.new)
      stub_const('Vault::HTTPError', Class.new(StandardError))
      vault_logical = double('VaultLogical')
      allow(Vault).to receive(:logical).and_return(vault_logical)
      allow(vault_logical).to receive(:write) do |_path, args|
        expect(args[:role_id]).to eq('file-role-id')
        expect(args[:secret_id]).to eq('file-secret-id')
        double(
          auth: double(
            client_token:   'hvs.fromfile',
            lease_id:       '',
            lease_duration: 3600,
            renewable:      true,
            policies:       ['default']
          )
        )
      end
    end

    it 'reads role_id from file when ENV is not set' do
      lease = identity.provide_token
      expect(lease).not_to be_nil
      expect(lease.credential).to eq('hvs.fromfile')
    end

    it 'strips trailing newline from file content' do
      lease = identity.provide_token
      expect(lease.credential).to eq('hvs.fromfile')
    end
  end

  describe 'file-based: non-existent file returns nil credentials' do
    before do
      allow(Legion::Extensions::Identity::Approle::Settings).to receive(:settings).and_return(
        role_id: nil, secret_id: nil,
        role_id_file:   '/nonexistent/vault-role-id',
        secret_id_file: '/nonexistent/vault-secret-id',
        auth_path: 'approle'
      )
    end

    it 'returns nil from provide_token when files do not exist' do
      expect(identity.provide_token).to be_nil
    end
  end
end
