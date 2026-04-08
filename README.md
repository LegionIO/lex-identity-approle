# lex-identity-approle

Vault AppRole identity provider for LegionIO. Machine identity for headless services.

## Overview

`lex-identity-approle` is a Phase 6 identity provider that authenticates to HashiCorp Vault using the AppRole auth method. It provides machine identity for Nomad jobs, K8s pods, and any headless service that needs to bind a Vault token at boot.

**Provider contract:**

| Attribute | Value |
|-----------|-------|
| `provider_name` | `:approle` |
| `provider_type` | `:auth` |
| `facing` | `:machine` |
| `priority` | `100` (highest — tried first among machine auth providers) |
| `trust_weight` | `100` |
| `capabilities` | `[:authenticate, :vault_auth]` |

## Credential Sources

`role_id` and `secret_id` are resolved in this order:

1. `Legion::Settings[:identity][:approle][:role_id]` / `[:secret_id]`
2. `ENV['VAULT_APPROLE_ROLE_ID']` / `ENV['VAULT_APPROLE_SECRET_ID']`
3. File mounts: `/run/secrets/vault-role-id` / `/run/secrets/vault-secret-id` (K8s default)

Override file paths via settings:

```json
{
  "identity": {
    "approle": {
      "role_id_file": "/custom/path/role-id",
      "secret_id_file": "/custom/path/secret-id",
      "auth_path": "approle"
    }
  }
}
```

## Single-Login Design

`resolve` calls `provide_token` internally. `provide_token` caches the returned Lease in `@cached_lease` and returns it on subsequent calls as long as it remains valid. This prevents double-consumption of single-use `secret_id` values (the Vault AppRole default is `secret_id_num_uses = 1`).

To use unlimited secret_ids, configure Vault with `secret_id_num_uses = 0`.

## Vault Routing

Uses `Legion::Crypt::LeaseManager.instance.logical` when available for namespace-aware routing. Falls back to `::Vault.logical` when legion-crypt is not loaded.

## Installation

Add to your `Gemfile`:

```ruby
gem 'lex-identity-approle'
```

## License

MIT
