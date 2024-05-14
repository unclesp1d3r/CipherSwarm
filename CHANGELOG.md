
<a name="v0.1.4"></a>
## [v0.1.4](https://github.com/unclesp1d3r/CipherSwarm/compare/v0.1.3...v0.1.4)

> 2024-05-11

### Added

* Added simple speakeasy keys for retries
* Added a reek file and started to clean up code smells

### Collapsed

* Collapsed migrations

### Exposed

* Exposed attack_mode_value in Attack API
* Exposed attack_mode_value in Attack API
* Exposed attack_mode_value in Attack API

### Increased

* Increased the precision of the hashcat benchmark speed

### Major

* Major changes to docker file to support esbuild

### Merge

* Merge branch 'hotfixfix_scan_js'

### Minor

* Minor openapi refinements

### Moved

* Moved from importmap to esbuild

### Removed

* Removed broken scan_js

### Slight

* Slight change to API for AgentUpdate

### Updated

* Updated the API with new server options


<a name="v0.1.3"></a>
## [v0.1.3](https://github.com/unclesp1d3r/CipherSwarm/compare/v0.1.2...v0.1.3)

> 2024-05-06

### Added

* Added counter_caches and fixed a bug in hash_items

### Updated

* Updated docker-deploy action


<a name="v0.1.2"></a>
## [v0.1.2](https://github.com/unclesp1d3r/CipherSwarm/compare/v0.1.1...v0.1.2)

> 2024-05-02

### Dependency Bumps

* Bump versions
* Bump docker/build-push-action from 2.5.0 to 5.3.0 ([#85](https://github.com/unclesp1d3r/CipherSwarm/issues/85))
* Bump docker/metadata-action from 3.3.0 to 5.5.1 ([#84](https://github.com/unclesp1d3r/CipherSwarm/issues/84))
* Bump docker/login-action from 1.10.0 to 3.1.0 ([#83](https://github.com/unclesp1d3r/CipherSwarm/issues/83))

### Replaced

* Replaced hash_mode enum with hash_type table ([#88](https://github.com/unclesp1d3r/CipherSwarm/issues/88))


<a name="v0.1.1"></a>
## [v0.1.1](https://github.com/unclesp1d3r/CipherSwarm/compare/v0.1.0...v0.1.1)

> 2024-04-30

### Significant

* Significant breaking changes to Agent API to fix codegen


<a name="v0.1.0"></a>
## v0.1.0

> 2024-04-30

### 29

* 29 finish implementing tests ([#35](https://github.com/unclesp1d3r/CipherSwarm/issues/35))

### 30

* 30 add a tasks dashboard ([#64](https://github.com/unclesp1d3r/CipherSwarm/issues/64))

### 36

* 36 migrate from apipie to rswag ([#42](https://github.com/unclesp1d3r/CipherSwarm/issues/42))

### 38

* 38 simplify down crackers ([#43](https://github.com/unclesp1d3r/CipherSwarm/issues/43))

### 56

* 56 grab device name from status ([#77](https://github.com/unclesp1d3r/CipherSwarm/issues/77))

### 9

* 9 add job creation UI inspired by hashcatlauncher ([#72](https://github.com/unclesp1d3r/CipherSwarm/issues/72))

### Add

* Add EditorConfig to maintain consistent coding styles

### Added

* Added a docker deploy action
* Added some ignores to resolve brakeman false warnings
* Added CodeClimate ([#28](https://github.com/unclesp1d3r/CipherSwarm/issues/28))
* Added admin dashboards, wordlist and hashlists
* Added basic API, cancancan, and crackers
* Added additional basic tests
* Added basic rspecs, fixtures, and documentation
* Added agents
* Added projects
* Added projects
* Added improved Docker support
* Added a basic admin page
* Added RubyMine to gitignore
* Added dependabot

### Basic

* Basic authentication support

### CircleCI

* CircleCI Commit ([#27](https://github.com/unclesp1d3r/CipherSwarm/issues/27))

### Cleaned

* Cleaned up install
* Cleaned up github workflows

### Combined

* Combined my CI files
* Combined my CI files

### Create

* Create LICENSE

### Dependency Bumps

* Bump jbuilder from 2.11.5 to 2.12.0 ([#82](https://github.com/unclesp1d3r/CipherSwarm/issues/82))
* Bump sidekiq from 7.2.2 to 7.2.4 ([#80](https://github.com/unclesp1d3r/CipherSwarm/issues/80))
* Bump pagy from 8.2.2 to 8.3.0 ([#81](https://github.com/unclesp1d3r/CipherSwarm/issues/81))
* Bump pagy from 8.2.1 to 8.2.2 ([#74](https://github.com/unclesp1d3r/CipherSwarm/issues/74))
* Bump rubocop from 1.63.2 to 1.63.3 ([#76](https://github.com/unclesp1d3r/CipherSwarm/issues/76))
* Bump pagy from 8.2.0 to 8.2.1 ([#73](https://github.com/unclesp1d3r/CipherSwarm/issues/73))
* Bump redis from 5.1.0 to 5.2.0 ([#68](https://github.com/unclesp1d3r/CipherSwarm/issues/68))
* Bump rubocop from 1.63.1 to 1.63.2 ([#69](https://github.com/unclesp1d3r/CipherSwarm/issues/69))
* Bump pagy from 8.1.2 to 8.2.0 ([#70](https://github.com/unclesp1d3r/CipherSwarm/issues/70))
* Bump pagy from 8.1.1 to 8.1.2 ([#63](https://github.com/unclesp1d3r/CipherSwarm/issues/63))
* Bump pagy from 8.1.0 to 8.1.1 ([#61](https://github.com/unclesp1d3r/CipherSwarm/issues/61))
* Bump audited from 5.5.0 to 5.6.0 ([#51](https://github.com/unclesp1d3r/CipherSwarm/issues/51))
* Bump pagy from 8.0.1 to 8.1.0 ([#58](https://github.com/unclesp1d3r/CipherSwarm/issues/58))
* Bump dockerfile-rails from 1.6.7 to 1.6.8 ([#57](https://github.com/unclesp1d3r/CipherSwarm/issues/57))
* Bump devise from 4.9.3 to 4.9.4 ([#60](https://github.com/unclesp1d3r/CipherSwarm/issues/60))
* Bump rubocop from 1.62.1 to 1.63.1 ([#59](https://github.com/unclesp1d3r/CipherSwarm/issues/59))
* Bump faker from 3.3.0 to 3.3.1 ([#46](https://github.com/unclesp1d3r/CipherSwarm/issues/46))
* Bump pagy from 7.0.11 to 8.0.1 ([#45](https://github.com/unclesp1d3r/CipherSwarm/issues/45))
* Bump audited from 5.4.3 to 5.5.0 ([#44](https://github.com/unclesp1d3r/CipherSwarm/issues/44))
* Bump debug from 1.9.1 to 1.9.2 ([#37](https://github.com/unclesp1d3r/CipherSwarm/issues/37))
* Bump pagy from 7.0.8 to 7.0.10
* Bump turbo-rails from 2.0.4 to 2.0.5
* Bump dockerfile-rails from 1.6.5 to 1.6.6
* Bump pagy from 7.0.7 to 7.0.8
* Bump pagy from 7.0.6 to 7.0.7

### Develop

* Develop ([#26](https://github.com/unclesp1d3r/CipherSwarm/issues/26))

### Fixed

* Fixed Github CI workflow. Probably.
* Fixed Github CI workflow. Probably.
* Fixed Github CI workflow. Probably.
* Fixed a glitch with Github CI
* Fixed a glitch with Github CI
* Fixed a glitch with Github CI
* Fixed a glitch with Github CI
* Fixed lints and added erblint

### Fixed

* fixed test in CI workflow

### Got

* Got rid of duplicate migration

### Initial

* Initial commit

### Massive

* Massive updates ([#20](https://github.com/unclesp1d3r/CipherSwarm/issues/20))

### Minor

* Minor version bumps of lock files
* Minor changes to markdownlint and Gemfile order
* Minor typo in README
* Minor cleanup and added devices column to agents

### More

* More cleanup from the merge

### Moved

* Moved to a proper state machine for tasks & attacks ([#50](https://github.com/unclesp1d3r/CipherSwarm/issues/50))
* Moved rubocop and brakeman to both dev and test

### Ran

* Ran bundle update
* Ran bundle update

### Removed

* Removed Rubocop from CodeClimate
* Removed CI from develop branch

### Rollback

* Rollback dependabot automerge

### Setup

* Setup stub circleci config
* Setup stub circleci config
* Setup stub circleci config
* Setup stub circleci config
* Setup stub circleci config
* Setup stub circleci config
* Setup stub circleci config
* Setup stub circleci config
* Setup stub circleci config
* Setup stub circleci config
* Setup stub circleci config
* Setup stub circleci config
* Setup Rubocop, brakeman, and workflows

### Split

* Split workflows

### Stubbed

* Stubbed out the client (agent) API to begin on agent
* Stubbed out the client (agent) API to begin on agent
* Stubbed out basic model rspec
* Stubbed out rspec to get it to pass

### Switched

* Switched CI to Rspect

### Synced

* Synced in a change to the README ([#12](https://github.com/unclesp1d3r/CipherSwarm/issues/12))

### Temporarily

* Temporarily disabled the rspec test in CI

### Trying

* Trying again to fix the workflow

### Update

* Update issue templates

### Updated

* Updated gitignore to be more comprehensive
* Updated test to include seed and fixed lint

