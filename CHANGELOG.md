
<a name="v0.3.4"></a>
## [v0.3.4](https://github.com/unclesp1d3r/CipherSwarm/compare/v0.3.3-20240622...v0.3.4)

> 2024-07-23

### Bug Fixes

* Completing the hash list now completes the campaign
* Hash list ingest now handles duplicate values correctly
* Allow longer hash values
* Made line_count larger on Rule and Word Lists
* Added text to confirm tasks are deleted with attacks

### Features

* Added ability to pause campaigns


<a name="v0.3.3-20240622"></a>
## [v0.3.3-20240622](https://github.com/unclesp1d3r/CipherSwarm/compare/v0.3.3...v0.3.3-20240622)

> 2024-06-22

### Bug Fixes

* Improved job queues fo high volume system


<a name="v0.3.3"></a>
## [v0.3.3](https://github.com/unclesp1d3r/CipherSwarm/compare/v0.3.2...v0.3.3)

> 2024-06-21

### Bug Fixes

* Removed duplicate notifications on index pages
* Word and Rule Lists now require a project if marked sensitive
* Jobs now retry 3 times when a record is not found
* Clean up excessive hashcat statuses

### Features

* Benchmark speed is now show in SI units
* Improved Large File Upload


<a name="v0.3.2"></a>
## [v0.3.2](https://github.com/unclesp1d3r/CipherSwarm/compare/v0.3.1...v0.3.2)

> 2024-06-17

### Features

* Added support for sending OpenCL device limits


<a name="v0.3.1"></a>
## [v0.3.1](https://github.com/unclesp1d3r/CipherSwarm/compare/v0.3.0-20240618...v0.3.1)

> 2024-06-17

### Bug Fixes

* Fixed issue with view hash list permission
* Standardized the titles of pages
* Fix issue with font broken on isolated network


<a name="v0.3.0-20240618"></a>
## [v0.3.0-20240618](https://github.com/unclesp1d3r/CipherSwarm/compare/v0.3.0-20240617...v0.3.0-20240618)

> 2024-06-16

### Bug Fixes

* Fixed minor bugs preventing deployment in docker


<a name="v0.3.0-20240617"></a>
## [v0.3.0-20240617](https://github.com/unclesp1d3r/CipherSwarm/compare/v0.3.0-20240616...v0.3.0-20240617)

> 2024-06-16

### Bug Fixes

* included master.key in docker container


<a name="v0.3.0-20240616"></a>
## [v0.3.0-20240616](https://github.com/unclesp1d3r/CipherSwarm/compare/v0.3.0...v0.3.0-20240616)

> 2024-06-15

### Bug Fixes

* Included master.key to fix deployment


<a name="v0.3.0"></a>
## [v0.3.0](https://github.com/unclesp1d3r/CipherSwarm/compare/v0.2.6...v0.3.0)

> 2024-06-14

### Bug Fixes

* Fix benchmark false positive
* Agents shutting down now abandon their tasks
* Fixed rule list link
* Minor form cleanup on hash lists and rules

### Code Refactoring

* Changed unprocessable_entity to unprocessable_content

### Features

* Add bidirectional status on heartbeat
* Update Agent to show errors and benchmarks
* Exposed agent advanced configuration


<a name="v0.2.6"></a>
## [v0.2.6](https://github.com/unclesp1d3r/CipherSwarm/compare/v0.2.5...v0.2.6)

> 2024-06-11

### Features

* Add bidirectional status on heartbeat
* Update Agent to show errors and benchmarks
* Exposed agent advanced configuration

### Bug Fixes

* Fixed rule list link

### Code Refactoring

* Changed unprocessable_entity to unprocessable_content


<a name="v0.2.5"></a>
## [v0.2.5](https://github.com/unclesp1d3r/CipherSwarm/compare/v0.2.4...v0.2.5)

> 2024-06-11

### Bug Fixes

* Minor form cleanup on hash lists and rules


<a name="v0.2.4"></a>
## [v0.2.4](https://github.com/unclesp1d3r/CipherSwarm/compare/v0.2.3...v0.2.4)

> 2024-06-06

### Features

* Add bidirectional status on heartbeat
* Update Agent to show errors and benchmarks
* Exposed agent advanced configuration


<a name="v0.2.3"></a>
## [v0.2.3](https://github.com/unclesp1d3r/CipherSwarm/compare/v0.2.2...v0.2.3)

> 2024-06-01

### Bug Fixes

* Add better logic for empty metadata in errors


<a name="v0.2.2"></a>
## [v0.2.2](https://github.com/unclesp1d3r/CipherSwarm/compare/v0.2.1...v0.2.2)

> 2024-06-01

### Bug Fixes

* Fix incorrect AgentError severity enum


<a name="v0.2.1"></a>
## [v0.2.1](https://github.com/unclesp1d3r/CipherSwarm/compare/v0.2.0...v0.2.1)

> 2024-06-01

### Features

* Add API for collecting agent errors
* Add Lazy Preloading throughout the app
* Add minio backend storage

### Documentation

* Updated annotations
* Update README and Changelog
* Add contribution documents

### Code Refactoring

* Add additional database rules
* Add ViewComponentContrib
* Standardize API names ([#103](https://github.com/unclesp1d3r/CipherSwarm/issues/103))

### Style Changes

* Remove Rails/ReversibleMigration cop

### Bug Fixes

* Remove broken viewcomponent generator
* Fix progress bar calculating


<a name="v0.2.0"></a>
## [v0.2.0](https://github.com/unclesp1d3r/CipherSwarm/compare/v0.1.7...v0.2.0)

> 2024-05-21

### Code Refactoring

* Rename api operations to be more consistent


<a name="v0.1.7"></a>
## [v0.1.7](https://github.com/unclesp1d3r/CipherSwarm/compare/v0.1.6...v0.1.7)

> 2024-05-21

### Documentation

* Update changelog with v0.1.6


<a name="v0.1.6"></a>
## [v0.1.6](https://github.com/unclesp1d3r/CipherSwarm/compare/v0.1.5...v0.1.6)

> 2024-05-20

### Documentation

* Tried to improve changelog

### Features

* Add ability to change password ([#97](https://github.com/unclesp1d3r/CipherSwarm/issues/97))

### Code Refactoring

* Add additional conventions to chglog


<a name="v0.1.5"></a>
## [v0.1.5](https://github.com/unclesp1d3r/CipherSwarm/compare/v0.1.4...v0.1.5)

> 2024-05-13


<a name="v0.1.4"></a>
## [v0.1.4](https://github.com/unclesp1d3r/CipherSwarm/compare/v0.1.3...v0.1.4)

> 2024-05-11


<a name="v0.1.3"></a>
## [v0.1.3](https://github.com/unclesp1d3r/CipherSwarm/compare/v0.1.2...v0.1.3)

> 2024-05-06


<a name="v0.1.2"></a>
## [v0.1.2](https://github.com/unclesp1d3r/CipherSwarm/compare/v0.1.1...v0.1.2)

> 2024-05-02


<a name="v0.1.1"></a>
## [v0.1.1](https://github.com/unclesp1d3r/CipherSwarm/compare/v0.1.0...v0.1.1)

> 2024-04-30


<a name="v0.1.0"></a>
## v0.1.0

> 2024-04-30

