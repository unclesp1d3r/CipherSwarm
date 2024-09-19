<a name="v0.6.0"></a>

## [v0.6.0](https://github.com/unclesp1d3r/CipherSwarm/compare/v0.5.4...v0.6.0)

> 2024-09-18

### Bug Fixes

* update schema and add task completion checks

  Renamed agent's 'active' field to 'enabled' and updated related comments in the schema. Added `mark_attacks_complete` callback in Campaign model to manage the task completion process dynamically. Refined task assignment logic in the Agent model to enhance performance and reliability.

* correct typos and streamline HTML elements

  Corrected a spelling error in the campaign model's comments and streamlined the table row ID and iteration syntax in the campaign and attack partials for better readability and consistency.

* ensure proper error handling and task updates

  Corrected error handling in task acceptance and alignment issues. Enhanced task update logic to prevent stale state overlap by excluding affected task IDs.

* display status for unprocessed line counts

  Previously, line counts were always shown even if they were not processed. Now, the view renders "pending" for items that haven't been processed, improving clarity for users.

* add set_projects before_action for new/edit/create/update

  Add a before_action to set accessible projects in both WordLists and RuleLists controllers. This ensures that project data is available for these actions, improving code consistency and maintainability.

* Fixed a 500 error on the activities page when there are no tasks for an attack

* Simplified the permissions structure and added extensive tests

  We were initially planning on having numerous roles per project, with different user levels having different capabilities, but that proved more complicated than it was worth. We removed all that, so any project member can manage anything within the project, but only a site admin can manage shared items. We then wrote extensive RSpec tests to validate this.

* Updated the count file lines job to simplify it.

* Added tests and improvements to Project and Agent access control

  We are implementing more granular control over abilities within the system, based not just on whether the user is an admin but also on their permissions on the projects associated with the resources. This cleanup effort involves writing controller tests to verify that permissions are working and fixing any situations where the tests fail. We started with the resources that aren’t children of projects.

* Resolved a minor issue with shared masks not showing up in the attack editor

* Resolved a weird bug breaking the docker builds

* Resolved a weird bug breaking the docker builds

* SubmitAgentError no longer generates a cascading error if task isn’t found

* Fixed an issue with the activity feed erroring when a mask list was running


### Code Refactoring

* correct typo in priority enum comment

  Fixed a typo in the campaign priority enum comment within the migration. Changed 'Defered' to 'Deferred' to ensure accurate documentation.

* rename agent field `active` to `enabled`

  Renamed the `active` field to `enabled` in the `Agent` model for better clarity. Updated associated views, tests, and database schema migration accordingly.

* Cleaned up code from RubyMine Analysis

  I cleaned up a bunch of stuff identified by RubyMine code analysis. There is no practical effect, except for a possible bug in the agent errors table that has not manifested yet.


### Features

* add priority to campaigns

  Introduced a priority enum to the Campaign model, with updated DB schema and associated logic. Enhanced CampaignsController to handle the new priority attribute and extended the Campaign model with new methods and callbacks for priority management.

* Attacks are now sorted by their complexity

  We did significant refactoring across the entire application, including adding comments to nearly every class to make it easier to understand and enhance IDE’s understanding of the objects. We also calculated how complex an attack and the various attack resources might be so that we could automatically sort attacks with the easiest ones first. I’m sure I missed something in the calculation, but it’s a start.

* Upgraded to Rails 7.2

* Added a blank slate component

  I added a blank slate component to all the index pages to show when there is nothing and instruct the user to add an item. I also cleaned up the loading of associated resources in the view files by moving them into the controller and making them more reliable.


<a name="v0.5.4"></a>

## [v0.5.4](https://github.com/unclesp1d3r/CipherSwarm/compare/v0.5.3-001...v0.5.4)

> 2024-09-02

### Bug Fixes

* Added rexml dependency



<a name="v0.5.3-001"></a>

## [v0.5.3-001](https://github.com/unclesp1d3r/CipherSwarm/compare/v0.5.3...v0.5.3-001)

> 2024-09-02

### Features

* Upgraded ruby and rails versions ([#181](https://github.com/unclesp1d3r/CipherSwarm/issues/181))

  * feat: Upgraded ruby and rails versions


* ci: Updated CircleCI config for new ruby


### Documentation

* Updated changelog format to include comments

  We use an automatic changelog generator (git-chglog) and often include comment bodies to explain a change in our commits further. This update to the configuration will now include those explanations.


### Test Changes

* Added basic controller tests and cleaned up identified issues

  I created bare stubs that test each controller action that is accessible via HTTP GET. This revealed a few routes that were either wholly unneeded or severely broken. I will continue adding more tests to flesh out the permissions model as I lock down some of the features to different roles.



<a name="v0.5.3"></a>

## [v0.5.3](https://github.com/unclesp1d3r/CipherSwarm/compare/v0.5.2...v0.5.3)

> 2024-08-28

### Features

* Updating an attack now resets it and makes it available


### Bug Fixes

* Resolved issue preventing the pause button from functioning



<a name="v0.5.2"></a>

## [v0.5.2](https://github.com/unclesp1d3r/CipherSwarm/compare/v0.5.1-001...v0.5.2)

> 2024-08-27


<a name="v0.5.1-001"></a>

## [v0.5.1-001](https://github.com/unclesp1d3r/CipherSwarm/compare/v0.5.1...v0.5.1-001)

> 2024-08-26

### Bug Fixes

* Added cascade on foreign keys to remove children of hash lists if hash lists are deleted

* Fixed major bug preventing creation of new campaigns



<a name="v0.5.1"></a>

## [v0.5.1](https://github.com/unclesp1d3r/CipherSwarm/compare/v0.5...v0.5.1)

> 2024-08-26

### Bug Fixes

* Resolved a weird bug breaking the docker builds

* SubmitAgentError no longer generates a cascading error if task isn’t found

* Fixed an issue with the activity feed erroring when a mask list was running



<a name="v0.5"></a>

## [v0.5](https://github.com/unclesp1d3r/CipherSwarm/compare/v0.4.2...v0.5)

> 2024-08-25

### Code Refactoring

* Minor cleanup of erb files

* DRY’d up the attack resources and fixed the attack validations


### Features

* Major improvements in visual consistency and UI

* Simplified attacks to only allow one each of resource files

  The attack logic was becoming incredibly unwieldy because we were supporting combinator attacks. Every other attack type allows a single word list, rule list, or mask list. Support for combinators broke the UI and made the data structures more complex. We removed combinators and recommend just precalculating the combinator attacks as word lists.

* Added soft deletion to attacks and campaigns


### Documentation

* Grammer-checked the primary project documents


### Bug Fixes

* Removed constraint on duplicate hashes

  There was a weird bug where the hash item would get created as a duplicate but could never be updated or cracked because it didn’t meet validation. While fixing this, I realized that we might actually want duplicate hashes because there may be multiple users with the same password in a dump, and the metadata would differentiate them.

* Agents only re-benchmark if they have no benchmarks

* Fix blank users being created

* Invalid benchmarks no longer block updates



<a name="v0.4.2"></a>

## [v0.4.2](https://github.com/unclesp1d3r/CipherSwarm/compare/v0.4.1...v0.4.2)

> 2024-08-06

### Bug Fixes

* Fixed issue with benchmarks not being submitted correctly

  For some reason, it only seemed to show up once we moved to benchmarking everything. Now, it is more resilient to write errors.

* Refactor of API to 1.4 to make it more standardized. ([#168](https://github.com/unclesp1d3r/CipherSwarm/issues/168))

* Significantly improved standardization of the API

  I made quite a few refactors to the agent API, but it is a significant breaking change.

MAJOR BREAKING CHANGE

* Tasks are no longer stale when the zaps are downloaded


### Features

* Agents are now notified if there’s new cracks or the task is paused

  BREAKING CHANGE



<a name="v0.4.1"></a>

## [v0.4.1](https://github.com/unclesp1d3r/CipherSwarm/compare/v0.4.0-20240729...v0.4.1)

> 2024-07-31

### Bug Fixes

* Changed the agent benchmarks to aggregate benchmarks

  For systems with multiple GPUs, the benchmark listing showed the speed of each GPU for the various hashes. While this might be useful for some, it was confusing and messy for most. It now adds the speeds of all GPUs for each hash, which more accurately reflects how Hashcat would use them.

* Removed unused agent properties

  We added several properties to smooth the transition from Hashtopolis, but they didn’t make sense for CipherSwarm’s use case. We have removed them to clean up the functionality.


### Documentation

* Removed FOSSA scan that never really worked


### Test Changes

* Restored test for ordered methods

  We used to test whether methods were in alphabetical order, but the Rubocop plugin that did that broke. Now that it’s working again, we are testing it again.


### Features

* Agents are now notified if there’s new cracks or the task is paused

  BREAKING CHANGE



<a name="v0.4.0-20240729"></a>

## [v0.4.0-20240729](https://github.com/unclesp1d3r/CipherSwarm/compare/v0.4...v0.4.0-20240729)

> 2024-07-29

### Bug Fixes

* Tasks are no longer stale when the zaps are downloaded


### Features

* Agents are now notified if there’s new cracks or the task is paused

  BREAKING CHANGE



<a name="v0.4"></a>

## [v0.4](https://github.com/unclesp1d3r/CipherSwarm/compare/v0.3.4...v0.4)

> 2024-07-29

### Features

* Agents are now notified if there’s new cracks or the task is paused

  BREAKING CHANGE



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

  This fixes an issue with a hash, word, or rules list being deleted before it was fully ingested and the processing job just continually trying forever.

* Clean up excessive hashcat statuses


### Features

* Benchmark speed is now show in SI units

* Improved Large File Upload

  The upload forms now use direct upload using Javascript to significantly improve performance and handle extremely large files.



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

  The theme we were using was trying to reach out to google fonts API and was causing the turbo refreshes to hang. Just switched back to the default bootstrap theme until we move to flowbite.



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

  We don't use any encrypted credentials, so there's no reason not to just include it. IF you publish your cipherswarm server publicly, you should change the master.key and the contents of the of the credentials



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

  BREAKING CHANGE

* Update Agent to show errors and benchmarks

  Also added support for enabling additional benchmark types, which will allow the agent to be used for those hash types

* Exposed agent advanced configuration



<a name="v0.2.6"></a>

## [v0.2.6](https://github.com/unclesp1d3r/CipherSwarm/compare/v0.2.5...v0.2.6)

> 2024-06-11

### Features

* Add bidirectional status on heartbeat

  BREAKING CHANGE

* Update Agent to show errors and benchmarks

  Also added support for enabling additional benchmark types, which will allow the agent to be used for those hash types

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

  BREAKING CHANGE

* Update Agent to show errors and benchmarks

  Also added support for enabling additional benchmark types, which will allow the agent to be used for those hash types

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

  The enum had an extra comma at the end of each word that shouldn’t have been there.



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

  * Updated the readme to mention the missing changes in the log.
* Updated the changelog git-chglog config to reflect the current conventional commits approach.

* Add contribution documents

  Added contributing instructions explaining the use of our coding standards. Also added a Code of Conduct.


### Code Refactoring

* Add additional database rules

* Add ViewComponentContrib

* Standardize API names ([#103](https://github.com/unclesp1d3r/CipherSwarm/issues/103))


### Style Changes

* Remove Rails/ReversibleMigration cop


### Bug Fixes

* Remove broken viewcomponent generator

* Fix progress bar calculating

  The tasks were showing the wrong progress due to a math issue.



<a name="v0.2.0"></a>

## [v0.2.0](https://github.com/unclesp1d3r/CipherSwarm/compare/v0.1.7...v0.2.0)

> 2024-05-21

### Code Refactoring

* Rename api operations to be more consistent

  BREAKING CHANGE

Renamed the various api endpoints to be more consistent with verbNoun in camelCase.



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

  Logged in users can now change their password by selecting from the user menu on the right of the menubar


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

