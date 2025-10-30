# Rails 8.0+ Upgrade Notes

## Overview

Successfully upgraded CipherSwarm from Rails 7.2 to Rails 8.0.4 as part of GitHub Issue #431.

## Changes Made

### 1. Core Framework Upgrade

- **Rails**: 7.2.2.1 → 8.0.4
- **Ruby**: 3.4.5 (no change required)
- **PostgreSQL**: Enhanced configuration for 17+ compatibility

### 2. Asset Pipeline Migration

**Removed:**
- `sprockets-rails`

**Added:**
- `propshaft` (1.3.1) - Modern asset pipeline for Rails 8

**Configuration Changes:**
- Updated `config/initializers/assets.rb` to support Propshaft
- Converted `app/assets/config/manifest.js` from Sprockets format to Propshaft
- Assets now automatically included from configured paths
- **Bootstrap Icons Fix**: Font loading configured to use node_modules directly
  - SCSS uses `~bootstrap-icons/font/fonts` path to reference fonts from node_modules
  - Works with dartsass-rails `--load-path=node_modules` configuration
  - No need to copy font files into app/assets/

### 3. Rails 8 Feature Additions

**New Dependencies:**
- `solid_cache` (1.0.8) - Database-backed caching for production
- `solid_cable` (3.0.12) - Database-backed ActionCable for real-time features
- `puma` upgraded to 6.0+

**Database Configuration:**
- Added multi-database support for cache and cable in production
- Enhanced PostgreSQL 17+ settings:
  - Statement timeout: 30s
  - Idle transaction timeout: 60s
  - Connection reaping for better pool management
  - Prepared statements enabled for performance

### 4. Gem Compatibility Changes

**Removed/Disabled:**
- `administrate-field-enum` - Incompatible with Rails 8, replaced with built-in `Field::Select`

**Updated Dashboard Fields:**
- `AgentDashboard`: `operating_system` now uses `Field::Select` with enum collection
- `ProjectUserDashboard`: `role` now uses `Field::Select` with enum collection

### 5. Configuration Updates

**Application Configuration (`config/application.rb`):**
- Updated `config.load_defaults` to `8.0`
- Maintained custom configurations:
  - ViewComponent autoload path
  - Eastern Time zone
  - Rack::Deflater middleware
  - Sidekiq queue adapter

**Production Configuration:**
- `solid_cache_store` for production caching
- Maintained Sidekiq for background jobs
- Minio storage configuration preserved

### 6. Test Suite Fixes

**Devise Integration:**
- Added `Warden.test_mode!` configuration for Rails 8 compatibility
- Added `Rails.application.reload_routes!` to ensure Devise mappings load correctly
- Fixed "Could not find a valid mapping" errors in request specs

**Test Results:**
- ✅ 570 model/unit tests passing
- ✅ 244 request/integration tests passing
- ✅ API contract tests (Rswag) passing
- ✅ Line coverage: 49-54%

## Breaking Changes

### For Developers

1. **Asset Pipeline**: If you manually managed asset precompilation with Sprockets directives, these are now obsolete. Propshaft automatically includes all assets.

2. **Administrate Enum Fields**: Custom dashboards using `Field::Enum` must be updated to use `Field::Select.with_options(collection: Model.enum_name.keys)`.

3. **Solid Cache/Cable**: Production deployments now require separate databases for cache and cable functionality. See `config/database.yml` for configuration.

4. **Bootstrap Icons**: Icon fonts are loaded directly from node_modules via Sass:
   - SCSS uses `~bootstrap-icons/font/fonts` to reference node_modules fonts
   - Compatible with dartsass-rails `--load-path=node_modules` setting
   - No asset copying required - fonts served directly from node_modules
   - To update: `yarn upgrade bootstrap-icons` and recompile CSS

### For Deployment

1. **Database Migrations**: Three database schemas are now managed:
   - Primary database: `db/schema.rb`
   - Cache database: `db/cache_schema.rb`
   - Cable database: `db/cable_schema.rb`

2. **Environment Variables**: Ensure `DATABASE_URL` and `REDIS_URL` are properly configured.

3. **Asset Compilation**: Run `rails assets:precompile` for production deployments.

## Rollback Procedure

If rollback to Rails 7.2 is necessary:

1. Revert Gemfile changes:
   ```ruby
   gem "rails", ">=7.2", "<8.0"
   gem "sprockets-rails"
   # Remove: propshaft, solid_cache, solid_cable
   # Re-enable: administrate-field-enum
   ```

2. Restore configuration files from git:
   ```bash
   git checkout origin/main -- config/application.rb config/environments/ config/database.yml
   ```

3. Revert dashboard changes:
   ```bash
   git checkout origin/main -- app/dashboards/
   ```

4. Revert test configuration:
   ```bash
   git checkout origin/main -- spec/rails_helper.rb
   ```

5. Run bundle install:
   ```bash
   bundle install
   ```

6. Restore asset manifest:
   ```bash
   git checkout origin/main -- app/assets/config/manifest.js
   ```

## Verification Steps

1. ✅ Application boots successfully
2. ✅ All tests pass (814 examples, 0 failures)
3. ✅ API endpoints maintain backward compatibility
4. ✅ Devise authentication works correctly
5. ✅ Asset pipeline serves assets properly
6. ✅ Admin dashboard functions correctly
7. ✅ Bootstrap icons display correctly

## Performance Improvements

- **Propshaft**: Faster asset compilation and modern tooling
- **Solid Cache**: Database-backed caching reduces Redis dependency
- **Solid Cable**: Scalable ActionCable for production deployments
- **Rails 8 Optimizations**: General framework performance improvements

## Next Steps

As per Issue #431, the following tasks depend on this upgrade:

- ✅ Task 1.1: Rails 8.0+ Core Dependencies Migration (COMPLETED)
- ⏳ Task 1.2: Tailwind CSS v4 Migration (requires Propshaft)
- ⏳ Task 1.3: Authentication System Modernization (requires Rails 8)
- ⏳ Task 3.1: ActionCable Infrastructure Setup (requires Rails 8 + Solid Cable)

## References

- [Rails 8.0 Upgrade Guide](https://guides.rubyonrails.org/upgrading_ruby_on_rails.html)
- [Propshaft Documentation](https://github.com/rails/propshaft)
- [Solid Cache Documentation](https://github.com/rails/solid_cache)
- [Solid Cable Documentation](https://github.com/rails/solid_cable)
- [GitHub Issue #431](https://github.com/unclesp1d3r/CipherSwarm/issues/431)

---

**Upgrade Date**: October 30, 2025
**Rails Version**: 8.0.4
**Status**: ✅ COMPLETED


