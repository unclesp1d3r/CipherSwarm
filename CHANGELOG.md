
0.1.5
=============
2024-05-14

* refactor Excluded vendor-managed items from codeclimate (79200733)
* merge 65 add a resource manager section for managing dictionaries and rule lists (#95) (ef1a7a69)
* Bump dockerfile-rails from 1.6.11 to 1.6.12 (#93) (614dc522)

0.1.4
=============
2024-05-12

* Merge branch 'hotfixfix_scan_js' (8a0b3f18)
* Removed broken scan_js (b262b6f2)
* Major changes to docker file to support esbuild (f724d62f)
* Collapsed migrations (97a3d05f)
* Moved from importmap to esbuild (40f50af1)
* Increased the precision of the hashcat benchmark speed (3786108f)
* Exposed attack_mode_value in Attack API (703975cf)
* Exposed attack_mode_value in Attack API (6403defe)
* Exposed attack_mode_value in Attack API (b2c8e6ec)
* Minor openapi refinements (a265cbf8)
* Added simple speakeasy keys for retries (4c3038bb)
* Updated the API with new server options (aefe69a8)
* Slight change to API for AgentUpdate (abcdaf3c)
* Added a reek file and started to clean up code smells (183fbbc1)

0.1.3
=============
2024-05-07

* Updated docker-deploy action (17d7d77e)
* Added counter_caches and fixed a bug in hash_items (9ea83abb)

0.1.2
=============
2024-05-03

* Replaced hash_mode enum with hash_type table (#88) (8468b923)
* Bump versions (21bb82ca)
* Bump docker/build-push-action from 2.5.0 to 5.3.0 (#85) (73b3ce08)
* Bump docker/metadata-action from 3.3.0 to 5.5.1 (#84) (2a3301b5)
* Bump docker/login-action from 1.10.0 to 3.1.0 (#83) (94edaed4)

0.1.1
=============
2024-05-01

* Significant breaking changes to Agent API to fix codegen (032ee92b)

0.1.0
=============
2024-04-30

* Added a docker deploy action (b36921a1)
* Bump jbuilder from 2.11.5 to 2.12.0 (#82) (2207b8eb)
* Bump sidekiq from 7.2.2 to 7.2.4 (#80) (9dfbdd7e)
* Bump pagy from 8.2.2 to 8.3.0 (#81) (1999e346)
* Rollback dependabot automerge (cc0737bc)
* 56 grab device name from status (#77) (bb084376)
* Bump pagy from 8.2.1 to 8.2.2 (#74) (7b9e06f2)
* Bump rubocop from 1.63.2 to 1.63.3 (#76) (235c6beb)
* Bump pagy from 8.2.0 to 8.2.1 (#73) (d6ba5c9b)
* 9 add job creation UI inspired by hashcatlauncher (#72) (b6683606)
* Bump redis from 5.1.0 to 5.2.0 (#68) (7d9e202f)
* Bump rubocop from 1.63.1 to 1.63.2 (#69) (28351b02)
* Bump pagy from 8.1.2 to 8.2.0 (#70) (ed2ea7f2)
* Bump pagy from 8.1.1 to 8.1.2 (#63) (b8d19447)
* 30 add a tasks dashboard (#64) (74f6ddba)
* Bump pagy from 8.1.0 to 8.1.1 (#61) (4888d025)
* Bump audited from 5.5.0 to 5.6.0 (#51) (576e7e4f)
* Bump pagy from 8.0.1 to 8.1.0 (#58) (47cab139)
* Bump dockerfile-rails from 1.6.7 to 1.6.8 (#57) (cb46b5e4)
* Bump devise from 4.9.3 to 4.9.4 (#60) (6cfa02c9)
* Bump rubocop from 1.62.1 to 1.63.1 (#59) (58e3dbd9)
* Moved to a proper state machine for tasks & attacks (#50) (a8e17b17)
* Bump faker from 3.3.0 to 3.3.1 (#46) (32619cc3)
* Bump pagy from 7.0.11 to 8.0.1 (#45) (349ea847)
* Bump audited from 5.4.3 to 5.5.0 (#44) (b35fc4a8)
* Fixed Github CI workflow. Probably. (02e14f62)
* Fixed Github CI workflow. Probably. (113d824d)
* Fixed Github CI workflow. Probably. (92869a78)
* Removed Rubocop from CodeClimate (d2b2993f)
* 38 simplify down crackers (#43) (fa1c7494)
* Minor version bumps of lock files (4132b649)
* Fixed a glitch with Github CI (762e0457)
* Fixed a glitch with Github CI (33ff9071)
* Fixed a glitch with Github CI (983f165f)
* Fixed a glitch with Github CI (72bf8536)
* Minor changes to markdownlint and Gemfile order (c0312d57)
* 36 migrate from apipie to rswag (#42) (e33b254c)
* Bump debug from 1.9.1 to 1.9.2 (#37) (666c9205)
* 29 finish implementing tests (#35) (341b9a4e)
* Added some ignores to resolve brakeman false warnings (8bf57318)
* Setup stub circleci config (018de35c)
* Setup stub circleci config (62ea96f7)
* Setup stub circleci config (d5ba6aa4)
* Setup stub circleci config (5a6fe810)
* Setup stub circleci config (e63ea3f6)
* Setup stub circleci config (4a69f7f5)
* Setup stub circleci config (95622f1e)
* Setup stub circleci config (cd7cb1e2)
* Setup stub circleci config (88ee9e9a)
* Setup stub circleci config (e8f809db)
* Setup stub circleci config (ba527daf)
* Setup stub circleci config (79ccf068)
* Added CodeClimate (#28) (2dea1248)
* CircleCI Commit (#27) (85c22a2c)
* Develop (#26) (202fbf13)
* Massive updates (#20) (e3cdb291)
* Temporarily disabled the rspec test in CI (2b487359)
* Synced in a change to the README (#12) (8ad1519f)
* Minor typo in README (c7da5d8e)
* Added admin dashboards, wordlist and hashlists (e7cdebdd)
* Added basic API, cancancan, and crackers (f1d67add)
* Added additional basic tests (3eba0f6b)
* Stubbed out the client (agent) API to begin on agent (a88df4c9)
* Stubbed out the client (agent) API to begin on agent (3a9aa574)
* Added basic rspecs, fixtures, and documentation (3c54c503)
* Minor cleanup and added devices column to agents (65937b90)
* Ran bundle update (3cc8a27e)
* Removed CI from develop branch (edbeeeb2)
* Added agents (f8be40bd)
* Updated gitignore to be more comprehensive (7e60a3b3)
* Bump pagy from 7.0.8 to 7.0.10 (d8473441)
* Bump turbo-rails from 2.0.4 to 2.0.5 (320f6e16)
* Bump dockerfile-rails from 1.6.5 to 1.6.6 (41614116)
* Ran bundle update (a7f105d6)
* Bump pagy from 7.0.7 to 7.0.8 (031dc85f)
* Combined my CI files (75894202)
* Combined my CI files (90e8c752)
* Added projects (170b270f)
* Added projects (35ae0cdd)
* Stubbed out basic model rspec (717eaaa9)
* Stubbed out rspec to get it to pass (bf915b6a)
* Added improved Docker support (1810906e)
* Bump pagy from 7.0.6 to 7.0.7 (79879c9d)
* Switched CI to Rspect (103d7b18)
* fixed test in CI workflow (48b7108f)
* Fixed lints and added erblint (fa1beb98)
* Trying again to fix the workflow (ac9cdd65)
* Updated test to include seed and fixed lint (cd3809fb)
* Split workflows (65a7c1d6)
* Moved rubocop and brakeman to both dev and test (63f65bde)
* Added a basic admin page (c7b3cea9)
* More cleanup from the merge (7ba59caa)
* Got rid of duplicate migration (c05a0604)
* Cleaned up install (2173fc88)
* Add EditorConfig to maintain consistent coding styles (f8d53815)
* Basic authentication support (3dc862e0)
* Cleaned up github workflows (55cb595b)
* Added RubyMine to gitignore (ab2dc07a)
* Create LICENSE (d8ec2e83)
* Setup Rubocop, brakeman, and workflows (ba436d34)
* Added dependabot (1472e7fb)
* Update issue templates (a1e34498)
* Initial commit (08b7a85e)

