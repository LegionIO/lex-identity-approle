# Changelog

## [0.1.0] - 2026-04-07

### Added

- Initial release
- `Identity` module implementing the LegionIO identity provider contract
- `provider_type: :auth`, `facing: :machine`, `priority: 100`, `trust_weight: 100`
- `capabilities: [:authenticate, :vault_auth]`
- `resolve` calls `provide_token` internally (single login, prevents double secret_id consumption)
- `provide_token` performs Vault AppRole login and returns a `Legion::Identity::Lease`
- Cached lease (`@cached_lease`) — prevents re-use of single-use secret_ids
- Expired-lease detection via `Lease#valid?`
- `role_id` and `secret_id` sourced from settings, ENV, or file mounts (K8s secret paths)
- Uses `Legion::Crypt::LeaseManager.instance.logical` for namespace-aware Vault routing when available
- Top-level delegation methods (`provider_name`, `provider_type`, `facing`) for extension registration
- `normalize` replaces non-alphanumeric chars (except `_` and `-`) with underscores
- Full spec coverage: provider contract, resolve, provide_token, settings, file-based credentials
