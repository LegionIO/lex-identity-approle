# lex-identity-approle: Vault AppRole Identity Provider for LegionIO

**Repository Level 3 Documentation**
- **Parent (Level 2)**: `/Users/miverso2/rubymine/legion/extensions/CLAUDE.md`
- **Parent (Level 1)**: `/Users/miverso2/rubymine/legion/CLAUDE.md`

## Purpose

Vault AppRole machine identity provider. Authenticates to Vault at boot via AppRole, caches the lease, and exposes the identity to the LegionIO framework. Greenfield gem — no existing AppRole code in the codebase.

**GitHub**: https://github.com/LegionIO/lex-identity-approle
**License**: MIT
**Version**: 0.1.0

## Architecture

```
Legion::Extensions::Identity::Approle
├── identity_provider? = true
├── remote_invocable?  = false
├── provider_name (delegates to Identity)
├── provider_type (delegates to Identity)
├── facing (delegates to Identity)
└── Identity    # provider contract: resolve, provide_token, normalize, ...
    Settings    # ENV + file-based credential loading
```

No runners, no actors, no transport helpers.

## File Map

| File | Purpose |
|------|---------|
| `lib/legion/extensions/identity/approle.rb` | Entry point: declares `identity_provider?`, `remote_invocable?`, delegation methods |
| `lib/legion/extensions/identity/approle/identity.rb` | Provider contract: `resolve`, `provide_token`, `normalize`, private helpers |
| `lib/legion/extensions/identity/approle/settings.rb` | Settings with ENV + Legion::Settings fallback |
| `lib/legion/extensions/identity/approle/version.rb` | `VERSION = '0.1.0'` |

## Provider Contract

| Method | Return |
|--------|--------|
| `provider_name` | `:approle` |
| `provider_type` | `:auth` |
| `facing` | `:machine` |
| `priority` | `100` |
| `trust_weight` | `100` |
| `capabilities` | `%i[authenticate vault_auth]` |
| `resolve` | identity hash or `nil` |
| `provide_token` | `Legion::Identity::Lease` or `nil` |
| `normalize(val)` | String |

## Key Rules

- `resolve` calls `provide_token` internally — single login per boot cycle
- `@cached_lease` prevents double-consumption of single-use secret_ids
- `private_class_method` with explicit method names: `build_lease`, `vault_approle_login`, `role_id`, `secret_id`, `read_file`, `settings`
- Uses `Legion::Crypt::LeaseManager.instance.logical` when available; falls back to `::Vault.logical`
- `normalize` replaces non-alphanumeric chars (except `_` and `-`) with underscores

## Settings

```json
{
  "identity": {
    "approle": {
      "role_id": null,
      "secret_id": null,
      "role_id_file": "/run/secrets/vault-role-id",
      "secret_id_file": "/run/secrets/vault-secret-id",
      "auth_path": "approle"
    }
  }
}
```

ENV fallbacks: `VAULT_APPROLE_ROLE_ID`, `VAULT_APPROLE_SECRET_ID`.

## Dependencies

| Gem | Purpose |
|-----|---------|
| `legion-json` | JSON serialization (framework compat) |
| `legion-settings` | Configuration management (framework compat) |

Runtime optional (not declared in gemspec):
- `vault` gem — used via `::Vault.logical` or `Legion::Crypt::LeaseManager`

## Testing

```bash
bundle install
bundle exec rspec     # full suite
bundle exec rubocop   # clean
```

---

**Maintained By**: Matthew Iverson (@Esity)
