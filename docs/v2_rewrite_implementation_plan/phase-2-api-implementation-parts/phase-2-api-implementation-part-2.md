<!-- section: web-ui-api -->

## 🌐 Web UI API (`/api/v1/web/*`)

These endpoints support the HTMX-based dashboard that human users interact with. They power views, forms, toasts, and live updates. Agents do not use these endpoints. All list endpoints must support pagination and query filtering.

---

⚠️ HTMX requires each of these endpoints to return **HTML fragments or partials**, not JSON. This is essential for proper client-side rendering and dynamic behavior. Every endpoint should return a rendered Jinja2 or equivalent template suitable for `hx-target` or `ws-replace` swaps.

🧭 These endpoints define the backend interface needed to support the user-facing views described in [Phase 3 - Web UI Foundation](../phase-3-web-ui-foundation.md). As you implement the frontend (Phase 3), be sure to reference this section to ensure every view or modal maps to a corresponding route here. We recommend annotating templates with source endpoint comments and may add cross-references in Phase 3 to maintain that alignment.

These endpoints support the HTMX-based dashboard that human users interact with. They power views, forms, toasts, and live updates. Agents do not use these endpoints. All list endpoints must support pagination and query filtering.

---

<!-- section: web-ui-api-campaign-management -->

### _🌟 Campaign Management_

<!-- section: web-ui-api-campaign-management-model-requirements -->

#### 🧩 Model Requirements

To fully support UI ordering, user-friendly attack summaries, and richer campaign lifecycle controls, the following model-level fields must be added or updated:

-   [x] Add `Attack.position: int` – numeric ordering field within a campaign `task_id:model.attack.position`
-   [x] Add `Attack.comment: Optional[str]` – user-provided description for UI display `task_id:model.attack.comment`
-   [x] Add `Attack.complexity_score: Optional[int]` – derived from keyspace or agent benchmarks, range 1–5 `task_id:model.attack.complexity_score`
-   [x] Optionally evolve `Campaign.active: bool` into `Campaign.state: Enum` (`draft`, `active`, `archived`, etc.) to support lifecycle toggles and clear workflow states `task_id:model.campaign.state_enum`

These fields must be integrated into campaign detail responses, sortable/queryable in the DB layer, and respected in API output.

---

<!-- section: web-ui-api-campaign-management-implementation-tasks -->

#### 🧩 Implementation Tasks

> [!NOTE]
> Some agent configuration and telemetry endpoints (e.g., fine-grained device toggles, temperature abort thresholds, hashcat backend flags) may not be fully supported by the current v1 Agent API.
>
> These are earmarked for Phase 5 implementation when Agent API v2 is introduced.
>
> Be sure to encapsulate such features behind feature flags or optional fields in the backend to avoid breaking compatibility.

> [!NOTE]
> Agent display name
>
> logic
> `display_name = agent.custom_label or agent.host_name`
>
> This fallback logic must be applied anywhere an agent is shown to the user. Include this behavior in both API response schemas and frontend template logic to ensure consistent display.

-   [x] Add `guid: UUID = uuid4()` field to `AttackResourceFile` to enable export/import referencing `task_id:model.resource.guid_support`
-   [x] Add `POST /api/v1/web/campaigns/{id}/reorder_attacks` to accept a list of attack IDs and persist order `task_id:campaign.reorder_attacks`
-   [x] Add `POST /api/v1/web/attacks/{id}/move` with direction (`up`, `down`, `top`, `bottom`) to reposition relative to other attacks `task_id:attack.move_relative`
-   [x] Add `POST /api/v1/web/attacks/{id}/duplicate` to clone an attack in-place `task_id:attack.duplicate`
-   [x] Add `DELETE /api/v1/web/attacks/bulk` to delete multiple attacks by ID `task_id:attack.bulk_delete`
-   [x] Add `POST /api/v1/web/campaigns/{id}/start` and `POST /api/v1/web/campaigns/{id}/stop` to manage lifecycle state `task_id:campaign.lifecycle_toggle`
-   [x] Add or enrich campaign attack view model to support: type label, length, friendly settings summary, keyspace, complexity, and user comments `task_id:campaign.attack_summary_viewmodel`
-   [x] `GET /api/v1/web/campaigns/` – List campaigns (paginated, filterable). Should support HTMX polling or WebSocket-driven update triggers to notify the browser when campaign progress changes and refresh the relevant list view. `task_id:campaign.list_view`
-   [x] `POST /api/v1/web/campaigns/` – Create a new campaign `task_id:campaign.create`
-   [x] `GET /api/v1/web/campaigns/{id}` – Campaign detail view with attacks/tasks `task_id:campaign.detail_view`
-   [x] `PATCH /api/v1/web/campaigns/{id}` – Update campaign `task_id:campaign.update`
-   [x] `DELETE /api/v1/web/campaigns/{id}` – Archive/delete campaign `task_id:campaign.archive_delete`
-   [x] `POST /api/v1/web/campaigns/{id}/add_attack` – Add attack to campaign `task_id:campaign.add_attack`
-   [x] `GET /api/v1/web/campaigns/{id}/progress` – Structure and return campaign progress/status fragment for HTMX polling `task_id:campaign.progress_fragment`
-   [x] `GET /api/v1/web/campaigns/{id}/metrics` – Aggregate stats (see items 3 and 5 of [Core Algorithm Implementation Guide](../core_algorithm_implementation_guide.md)) `task_id:campaign.metrics_summary`
-   [x] `POST /api/v1/web/campaigns/{id}/relaunch` – Relaunch attack if previously failed, or if any linked resource (wordlist, mask, rule) has been modified since the last run. Requires re-validation and explicit user confirmation. `task_id:campaign.rerun_attack`

---

<!-- section: web-ui-api-attack-management -->

### _💥 Attack Management_

<!-- section: web-ui-api-campaign-management-ux-design-goals -->

#### 🧩 UX Design Goals

These design goals are for the attack editor modal and should be applied to the fragment sent to the client. Though not exclusively API-related, these are important considerations for the API implementation and will be finalized in Phase 3 with the full user interface implementation. After adding the appropriate supporting functionality to the models and endpoints, Skirmish should add stub templates for these views with TODO comments to ease implementing phase 3 frontend.

##### 🔁 Common Editing Features

-   [x] Dynamically update keyspace and complexity score for unsaved changes `task_id:attack.ux_estimate_unpersisted`
-   [x] Show these values in attack editor view like campaign detail view `task_id:attack.ux_estimate_view`
-   [x] Warn and require confirmation when editing an `exhausted` or `running` attack `task_id:attack.ux_edit_lifecycle_reset`
-   [x] Confirming edit resets attack to `pending` and triggers reprocessing `task_id:attack.ux_edit_lifecycle_reset`
-   [x] Allow export/import of JSON files for Attack or Campaign (supports template reuse) `task_id:attack.ux_export_import_json`

##### 📚 Dictionary Attack UX

See [New Dictionary Attack Editor](../notes/ui_screens/new_dictionary_attack_editor.md) for more details.

-   [x] Min/max length fields default to typical hash type range (e.g., 1–32) `task_id:attack.ux_dictionary_length_defaults`
-   [x] Wordlist dropdown with search, sorted by last modified, includes entry count `task_id:attack.ux_dictionary_wordlist_dropdown`
-   [x] "Modifiers" button group for non-expert users (e.g., `+ Change Case`, `+ Substitute Characters`) in dictionary attack editor (`task_id:attack.ux_dictionary_modifiers`)
-   [x] Optional rule list dropdown for expert users `task_id:attack.ux_dictionary_rule_dropdown`
    -   This should be a [Searchable Dropdown](https://flowbite.com/docs/components/dropdowns/#dropdown-with-search) that allows the user to search for a rule by name and select one.
-   [x] Support "Previous Passwords" as dynamic wordlist option `task_id:attack.ux_dictionary_previous_passwords`
    -   This will automatically generate a dynamic wordlist from the previous project's cracked passwords. When this option is select, the wordlist dropdown and the option for ephemeral wordlist should be hidden. The dynamic wordlist is not persisted and is generated on the fly when the attack is run or rerun.
-   [x] Support ephemeral wordlist field with "Add Word" UI for small lists `task_id:attack.ux_dictionary_ephemeral_wordlist`
    -   This should be a [Flowbite Text Input](https://flowbite.com/docs/forms/input/) with a "+" button to add a new word. The words should be persisted in the attack resource file and used as a generated wordlist when the attack is run.

##### 🎭 Mask Attack UX

See [New Mask Attack Editor](../notes/ui_screens/new_mask_attack_editor.md) for more details.

<!-- Note to AI: Please work on the section below "web-ui-api-campaign-management-implementation-tasks" before proceeding with this section. -->

-   [x] Add/remove inline mask lines (ephemeral mask list) `task_id:attack.ux_mask_inline_lines`
-   [x] Validate mask syntax in real-time `task_id:attack.ux_mask_syntax_validation`
    -   This should follow hashcat's mask syntax restrictions. This applies to the mask input field implemented in `task_id:attack.ux_mask_inline_lines` and the validation should be triggered when the user leaves the input field.
-   [x] Ephemeral mask list stored only with the attack, deleted when attack is removed `task_id:attack.ux_mask_ephemeral_storage`
-   [x] Add/remove inline mask lines (ephemeral mask list) `task_id:attack.ux_mask_inline_lines`
    -   This should be a [Flowbite Text Input](https://flowbite.com/docs/forms/input/) with a "+" button to add a new word. The masks should be persisted in the attack resource file and used as a generated mask list when the attack is run.

##### 🔢 Brute Force UX

See [New Brute Force Attack Editor](../notes/ui_screens/brute_force_attack_editor.md) for more details.

<!-- Note to AI: Please work on the section below "web-ui-api-campaign-management-implementation-tasks" before proceeding with this section. -->

-   [x] Checkbox UI for charset selection (`Lowercase`, `Uppercase`, `Numbers`, `Symbols`, `Space`) `task_id:attack.ux_brute_force_charset_selection`
    -   Each charset maps to a mask token for the `?1` character (i.e. `?l` for lowercase, etc.). The user should be able to select one or more charsets and the selected charsets should be used to generate the mask.
-   [x] Range selector for mask length (min/max) `task_id:attack.ux_brute_force_length_selector`
    -   This should be a [Flowbite Range Slider](https://flowbite.com/docs/forms/range/) and it is used to set the `min_length` and `max_length` of the the incremental attack.
    -   The max length is also used to set the number of `?1` tokens in the mask (see `task_id:attack.ux_brute_force_mask_generation`)
-   [x] Automatically generate `?1?1?...` style mask based on selected length `task_id:attack.ux_brute_force_mask_generation`
    -   The brute force attack is just a user friendly way to generate an increment attack with a mask. The mask is generated by the `?1` token which is repeated for the length of the maximum character length (defined by the `max_length` in `task_id:attack.ux_brute_force_length_selector`). The selected character types are used to set the tokens used in the custom character set 1 for the attack.
-   [ ] Derive `?1` charset from selected charsets (e.g., `?l?d` for lowercase + digits) `task_id:attack.ux_brute_force_charset_derivation`
    -   This is determined from the character types chosen in `task_id:attack.ux_brute_force_charset_selection` and should be set as the `custom_charset_1` for the attack.

---

<!-- section: web-ui-api-campaign-management-implementation-tasks -->

#### 🧩 Implementation Tasks

_Includes support for a full-featured attack editor with configurable mask, rule, wordlist resources; charset fields; and validation logic. Endpoints must power form-based creation, preview validation, reordering, and config visualization._

Note: See [Attack Notes](docs/v2_rewrite_implementation_plan/notes/attack.md) for more details on the attack editor UX and implementation.

-   [x] Implement `POST /attacks/validate` for dry-run validation with error + keyspace response `task_id:attack.validate`
-   [x] Validate resource linkage: masks, rules, wordlists must match attack mode and resource type (task_id: resource-linkage-validation)
-   [x] Support creation via `POST /attacks/` with full config validation `task_id:attack.create_endpoint`
-   [x] Return Pydantic validation error format on failed creation `task_id:attack.create_validation_error_format`
-   [ ] Support reordering attacks in campaigns (if UI exposes it) `task_id:attack.reorder_within_campaign`
    -   This is implemented in `task_id:attack.move_relative` on the backend implemented as buttons at the bottom of the campaign detail view (see `docs/v2_rewrite_implementation_plan/notes/campaigns.md` for more details)
-   [ ] Implement performance summary endpoint: `GET /attacks/{id}/performance` `task_id:attack.performance_summary`
    -   This supports the display of a text summary of the attack's hashes per second, total hashes, and the number of agents used and estimated time to completion. See items 3 and 3b in the [Core Algorithm Implementation Guide](../core_algorithm_implementation_guide.md) for more details. This should be live updated via websocket when the attack status changes (see `task_id:attack.live_updates_htmx`).
-   [ ] Implement toggle: `POST /attacks/{id}/disable_live_updates` `task_id:attack.disable_live_updates`
    -   This enables and disables the websocket live updates for the attack. When disabled, the attack will not receive live updates and the UI will not update when the attack status changes (see `task_id:attack.live_updates_htmx`).
-   [ ] All views must return HTML fragments (not JSON) suitable for HTMX rendering `task_id:attack.html_fragments_htmx`.
-   [ ] All views should support WebSocket/HTMX auto-refresh triggers `task_id:attack.live_updates_htmx`
    -   A websocket endpoint needs to be implemented on the backend to notify the client the attack status (progress, status, etc.) has changed. A fronend functionality will need to be implemented to handle the websocket events and update the UI accordingly using [HTMX `htmx-ext-ws`](https://htmx.org/extensions/ws/)
-   [ ] Add human-readable formatting for rule preview (e.g., rule explanation tooltips) `task_id:attack.rule_preview_explanation`
    -   This is implemented in `task_id:attack.rule_preview_explanation` on the backend and displays a tooltip with the rule explanation when the user hovers over the rule name in the rule dropdown.
-   [ ] Implement default value suggestions (e.g., for masks, charset combos) `task_id:attack.default_config_suggestions`
    -   This is implemented in `task_id:attack.default_config_suggestions` on the backend and displays a dropdown of suggested masks, charsets, and rules for the attack.

_All views should support HTMX WebSocket triggers or polling to allow dynamic refresh when agent-submitted updates occur._

-   [ ] `GET /api/v1/web/attacks/` – List attacks (paginated, searchable) `task_id:attack.list_paginated_searchable`
-   [ ] `POST /api/v1/web/attacks/` – Create attack with config validation `task_id:attack.ux_created_with_validation`
    -   This supports the creation of a new attack with validation of the attack's config using pydantic validation.
-   [ ] `GET /api/v1/web/attacks/{id}` – View attack config and performance `task_id:attack.ux_view_config_performance`
    -   This supports the display of the attack's config and performance information in a modal when the user clicks on an attack in the campaign detail view.
-   [ ] `PATCH /api/v1/web/attacks/{id}` – Edit attack `task_id:attack.ux_edit_attack`
    -   This supports the editing of the attack's config in a modal when the user clicks on an attack in the campaign detail view.
-   [ ] `DELETE /api/v1/web/attacks/{id}` – Delete attack `task_id:attack.ux_delete_attack`
    -   This deletes an attack from the campaign. The attack should be removed from the campaign. If the attack has not been started, it should be deleted from the database.
    -   If the attack has been started, it should be marked as deleted and the attack should be stopped.
        -   Any ephemeral resources should be deleted from deleted attacks, but non-ephemeral resources should be unlinked from the attack.
-   [ ] `POST /api/v1/web/attacks/validate` – Return validation errors or keyspace estimate (see [Core Algorithm Implementation Guide](../core_algorithm_implementation_guide.md)) `task_id:attack.validate_errors_keyspace`
-   [ ] `GET /api/v1/web/attacks/{id}/performance` – Return task/agent spread, processing rate, and agent participation for a given attack.
    -   Used to diagnose bottlenecks or performance issues by surfacing which agents worked the task, their individual speed, and aggregate throughput.
    -   Useful for verifying whether a slow campaign is due to insufficient agent coverage or unexpectedly large keyspace. `task_id:attack.performance_diagnostics`
-   [ ] `POST /api/v1/web/attacks/{id}/disable_live_updates` – Toggle WS/HTMX sync `task_id:attack.disable_live_updates`
    -   This enables and disables the websocket live updates for the attack. When disabled, the attack will not receive live updates and the UI will not update when the attack status changes (see `task_id:attack.live_updates_htmx`).

---

<!-- section: web-ui-api-campaign-management-save-load-schema-design -->

#### 🧩 Save/Load Schema Design

CipherSwarm should allow saving and loading of both individual Attacks and entire Campaigns via a custom JSON format. This will support backup, sharing, and preconfiguration workflows.

🔐 The exported format must include:

-   All editable fields of the attack or campaign, including position and comment
-   For campaigns: the order of attached attacks must be preserved
-   Any ephemeral word or mask lists used by an attack must be serialized as inline content
-   For linked non-ephemeral resources (wordlists, masks, rules), include their stable UUID (`guid`) for re-linking

🚫 The exported format must **not** include:

-   Project ID or User ID bindings
-   Internal database primary keys

📥 On import:

-   The backend must validate schema correctness
-   Rehydrate ephemeral resources directly
-   Look up non-ephemeral resources by GUID (`AttackResourceFile.guid`)
-   Prompt the user or fail gracefully if a GUID reference does not resolve

This schema should be versioned and tested against a validation spec.

A new `guid: UUID` field must be added to the `AttackResourceFile` model to support this. It should be unique, stable across sessions, and used as the canonical identifier for serialization workflows. The GUID should be generated using `uuid4()` at the time the resource is first created, and must remain immutable and internal-only (not exposed to Agent APIs).

If a resource referenced by GUID cannot be matched during import (either due to deletion or lack of permission), the user must be prompted with three fallback options:

1. **Select a Replacement** – Choose a compatible resource of the same `resource_type` from a dropdown
2. **Skip Affected Attack** – Import the rest of the campaign, omitting attacks missing required resources
3. **Abort Import** – Cancel the import entirely

All fallback logic should be implemented server-side with support for frontend prompting. to support this. It should be unique, stable across sessions, and used as the canonical identifier for serialization workflows. of both individual Attacks and entire Campaigns via a custom JSON format. This will support backup, sharing, and preconfiguration workflows.

🔐 The exported format must include:

-   All editable fields of the attack or campaign, including position and comment
-   For campaigns: the order of attached attacks must be preserved
-   Any ephemeral word or mask lists used by an attack must be serialized as inline content

🚫 The exported format must **not** include:

-   Project ID or User ID bindings
-   Hash list references (campaigns must be re-linked to a hash list upon import)
-   Internal database IDs

📥 On import:

-   The backend must validate schema correctness
-   Attachments to new or existing campaigns must be confirmed explicitly
-   Inline ephemeral resources must be rehydrated as temporary DB records

This schema should be versioned and tested against a validation spec.

---

#### Ephemeral Resources

<!-- section: web-ui-api-ephemeral-resources -->

Attacks can support ephemeral resources that can be created and edited within the attack editor. These resources are still persisted to the database, but they are stored as part of an AttackResourceFile record as a JSON structure, and are not visible in the Resource Browser or available for reuse in other attacks. They are deleted when the attack is deleted, they do not have a backing file in S3, and they are exported inline if the attack is exported within the same JSON file. The Agent API will provide a non-signed URL to agents to access these resources when the attack is running and they are downloaded directly from CipherSwarm, rather than the MinIO service.

---

<!-- section: web-ui-api-campaign-management-extended-implementation-tasks -->

#### 🧩 Extended Implementation Tasks

These tasks expand the attack editing interface and logic to support contextual UIs, one-off resources, and user-friendly modifiers without exposing raw hashcat details.

-   [x] Implement `POST /api/v1/web/attacks/estimate` to return keyspace + complexity score for unsaved attack input `task_id:attack.estimate_unpersisted` (see [Phase 2 Implementation Tasks](../phase-2-api-implementation-tasks.md#hash-guessing-logic))
-   [x] Add edit-protection logic to warn if attack is `running` or `completed` before allowing edit (Web UI API) `task_id:attack.edit_protect`
-   [x] Support ephemeral inline wordlists (multiple `add word` fields) stored in memory or DB during attack creation, deleted when the attack is deleted. (Web UI API) `task_id:attack.ephemeral_wordlist`
-   [x] Support ephemeral inline masks (`add mask` line interface) with same lifecycle behavior `task_id:attack.ephemeral_masklist` (see section [Ephemeral Resources](#ephemeral-resources) above)
-   [ ] Implement "Modifiers" UI: map toggled options (change case, swap characters, etc.) to preselected rules files under the hood `task_id:attack.modifier_ui_to_rules`
-   [ ] Dictionary attack UI must support: min/max length, searchable wordlist dropdown (sorted by last modified), option to use dynamic wordlist from previous project cracks `task_id:attack.dictionary_ui_controls`
    -   See [Dictionary Attack UX](#dictionary-attack-ux) for more details.
-   [x] Brute force UI must allow checkbox-driven charset selection, range selector, and generate corresponding `?1?1?...` style masks and `?1` custom charset `task_id:attack.brute_force_ui_logic` (strong typing enforced)
-   [x] Add support to export any single Attack or entire Campaign to a JSON file `task_id:attack.export_json`
-   [ ] Add support to load campaign or attack JSON file and prefill the editor `task_id:attack.import_json_schema`
    -   See [Save/Load Schema Design](#save-load-schema-design) for more details.

The attack editor must support a modal-based, multi-form interface with per-attack-type customization. It should dynamically update keyspace estimates and complexity scores as the user changes input.

-   ⚙️ The editor must show real-time keyspace and complexity values, even for non-persisted attacks. Backend support is needed for live estimation.
-   ⚠️ Editing an attack that is already running or exhausted must trigger a confirmation prompt and reset the state if confirmed. This restarts the attack lifecycle.
-   ✍️ User-facing options should be simplified (e.g. "+ Change Case") and map to hashcat rule resources internally.
-   🔁 Certain attack types (e.g., dictionary, brute force) must support one-off word/mask lists that are ephemeral and attack-local.

---

<!-- section: web-ui-api-agent-management -->

### _⚙️ Agent Management_

#### 🧩 UX Design Goals

##### 🖥️ Agent List View

-   Everyone can see all agents and their state
-   Admin-only gear menu (Disable Agent / View Details)
-   Columns:

    -   Agent Name + OS
    -   Status
    -   Temp (°C) and Utilization (avg of enabled devices)
    -   Current and Average Attempts/sec
    -   Current Job (Project, Campaign, Attack)

##### ➕ Agent Registration

-   Modal to enter label and select Projects (multi-toggle)

    -   Upon creating a new agent, the UI must immediately display the generated token for copy/paste. Tokens are only shown once.

-   Upon save, display generated token to admin

##### ⚙️ Agent Detail Tabs

###### 🔧 Settings

-   `display_name = agent.custom_label or agent.host_name`
-   Toggle: Enabled/Disabled
-   Agent Update Interval (sec, default randomized 1–15)
-   Toggle: Use Native Hashcat (sets `AdvancedAgentConfiguration.use_native_hashcat = true`)
-   Toggle: Enable Additional Hash Types (`--benchmark-all`)
-   List: Project assignment toggles
-   Static: OS, IP, Signature, Token

###### 🖥️ Hardware

-   List of backend devices from `--backend-info`
-   Toggle each device on/off → updates `backend_device`
-   Device toggling prompts: Apply now / Next Task / Cancel if task is running
-   Show gray placeholder if no devices reported yet
-   HW Settings:

    -   `--hwmon-temp-abort` (note only, default to 90°C)

        -   Note: This field is not yet supported by the v1 Agent API, but could be added safely to `AdvancedAgentConfiguration` as an optional key. The agent will ignore unknown fields.

    -   OpenCL Device Type selector (`opencl_devices`)

-   Backend toggles: CUDA, HIP, Metal, OpenCL → affect `--backend-ignore-*`

###### 📈 Performance

-   Line chart of `DeviceStatus.guess_rate` over time (8hr window)
-   Donut chart per device within card: Utilization as a percentage (or N/A)
-   Live updating via WebSocket

###### 🪵 Log

-   Timeline of `AgentError` entries
-   Color-coded severity
-   Fields: message, code, task link, details

###### 🧠 Capabilities

-   Pulls from `HashcatBenchmark`
-   Table (rollup view): Toggle / Hash ID / Name / Speed / Category
-   Expandable rows per device
-   Filterable + searchable
-   Caption with benchmark timestamp
-   Header button to trigger benchmark (sets `agent.state = pending`)

---

<!-- section: web-ui-api-agent-management-implementation-tasks -->

#### 🧩 Implementation Tasks

-   [ ] `GET /api/v1/web/agents/` – List/filter agents `task_id:agent.list_filter`
    -   This will display a list of agents as described in the [Agent List View](#agent-list-view) section.
-   [ ] `GET /api/v1/web/agents/{id}` – Detail view `task_id:agent.detail_view`
    -   This will display a detailed view of the agent as described in the [Agent Detail Tabs](#agent-detail-tabs) section.
-   [ ] `PATCH /api/v1/web/agents/{id}` – Toggle enable/disable `task_id:agent.toggle_state`
    -   This will be a toggle in the list of agents that changes the agent's `enabled` state and prevents the agent from picking up new tasks.
-   [ ] `POST /api/v1/web/agents/{id}/requeue` – Requeue failed task `task_id:agent.manual_requeue`
    -   This will requeue a failed task for the agent. It should take a `task_id` as a parameter and requeue the task for the same agent unless the task is associated with an attack that has been completed, deleted, or otherwise invalidated.
-   [ ] `GET /api/v1/web/agents/{id}/benchmarks` – View benchmark summary `task_id:agent.benchmark_summary`
    -   This will display a summary of the agent's benchmark results as described in the [Agent Detail Tabs](#agent-detail-tabs) section. See also [Agent Benchmark Compatibility](../core_algorithm_implementation_guide.md#agent-benchmark-compatibility) for more details.
-   [ ] `POST /api/v1/web/agents/{id}/test_presigned` – Validate URL access `task_id:agent.presigned_url_test`
    -   This will validate the presigned URL for the agent. It should take a `url` as a parameter and return a boolean value indicating whether the URL is valid. See [Phase 2b: Resource Management](../phase-2b-resource-management.md) for more details.
-   [ ] `PATCH /api/v1/web/agents/{id}/config` – Update `AdvancedAgentConfiguration` toggles (backend_ignore, opencl, etc.) `task_id:agent.config_update`
-   [ ] `PATCH /api/v1/web/agents/{id}/devices` – Toggle individual backend devices (stored as stringified int list) `task_id:agent.device_toggle`
    -   This will toggle the individual backend devices for the agent. It should take a `devices` as a parameter and update the `backend_device` for the agent.
    -   The backend devices are stored in Cipherswarm on the Agent model as `list[str]` of their descriptive names in `Agent.devices` and the actual setting of what should be enabled is a comma-seperated list of integers, 1-indexed, so it'll be a little weird to figure out. We'll probably need a better way to do this in the future, but this is a limitation of v1 of the Agent API. See [Hardware](#hardware) above for more details.
-   [ ] `POST /api/v1/web/agents/{id}/benchmark` – Trigger new benchmark run (set to `pending`) `task_id:agent.benchmark_trigger`
    -   This changes the agent's state to `pending`, which causes the agent to run a benchmark. See [Agent Benchmark Compatibility](../core_algorithm_implementation_guide.md#agent-benchmark-compatibility) for more details.
-   [ ] `GET /api/v1/web/agents/{id}/errors` – Fetch structured log stream `task_id:agent.log_stream`
    -   This will fetch the structured log stream for the agent. It should return a list of `AgentError` entries as described in the Logs section of the [Agent Detail Tabs](#agent-detail-tabs) above. The log stream should be updated in real-time as new errors are reported and should use a human-readable visual style, color-coding, etc.
-   [ ] `GET /api/v1/web/agents/{id}/performance` – Stream guesses/sec time series `task_id:agent.performance_graph`
    -   This will stream the guesses/sec time series for the agent. It should return a list of `DeviceStatus` entries as described in the [Agent Detail Tabs](#agent-detail-tabs) section.
    -   This will be used to populate Flowbite Charts using the [ApexCharts library](https://flowbite.com/docs/plugins/charts/). See [Agent Performance Graph](#performance) above for more details.
-   [ ] `POST /api/v1/web/agents` – Register new agent + return token `task_id:agent.create`
    -   This will register a new agent and return a token for the agent. See [Agent Registration](#agent-registration) above for more details.
-   [ ] `GET /api/v1/web/agents/{id}/hardware` – Report backend devices, temp limits, platform support flags `task_id:agent.hardware_detail`
    -   This will report the backend devices, temp limits, and platform support flags for the agent. See [Hardware](#hardware) above for more details.
-   [ ] `PATCH /api/v1/web/agents/{id}/hardware` – Update hardware limits + platform toggles `task_id:agent.hardware_update`
    -   This will update the hardware limits and platform toggles for the agent. See [Hardware](#hardware) above for more details.
-   [ ] `GET /api/v1/web/agents/{id}/capabilities` – Show benchmark results (table + graph) `task_id:agent.capabilities_table` - This will show the benchmark results for the agent. See [Agent Capabilities](#capabilities) above for more details. See also [Agent Benchmark Compatibility](../core_algorithm_implementation_guide.md#agent-benchmark-compatibility) for more details.

_Includes real-time updating views, hardware configuration toggles, performance monitoring, and error visibility. Most endpoints should use HTMX/WebSocket triggers to refresh data without full page reloads._ should be supported on list and detail views for dynamic agent status refresh.\*

-   [ ] `GET /api/v1/web/agents/` – List/filter agents `task_id:agent.list_filter`
    -   This will display a list of agents as described in the [Agent List View](#agent-list-view) section. This should be a flowbite datatable with the columns and filters as described in the [Agent List View](#agent-list-view) section.
-   [ ] `GET /api/v1/web/agents/{id}` – Detail view `task_id:agent.detail_view`
    -   This will display a detailed view of the agent as described in the [Agent Detail Tabs](#agent-detail-tabs) section. This should be a flowbite modal with the tabs and content as described in the [Agent Detail Tabs](#agent-detail-tabs) section.
-   [ ] `PATCH /api/v1/web/agents/{id}` – Toggle enable/disable `task_id:agent.toggle_state`
    -   This will be a toggle in the list of agents that changes the agent's `enabled` state and prevents the agent from picking up new tasks.
-   [ ] `POST /api/v1/web/agents/{id}/requeue` – Requeue failed task `task_id:agent.manual_requeue`
-   [ ] `GET /api/v1/web/agents/{id}/benchmarks` – View benchmark summary `task_id:agent.benchmark_summary`
    -   This will display a summary of the agent's benchmark results as described in the [Agent Detail Tabs](#agent-detail-tabs) section. See also [Agent Benchmark Compatibility](../core_algorithm_implementation_guide.md#agent-benchmark-compatibility) for more details.
-   [ ] `POST /api/v1/web/agents/{id}/test_presigned` – Validate URL access `task_id:agent.presigned_url_test`

---

<!-- section: web-ui-api-resource-browser -->

### _📁 Resource Browser_

CipherSwarm uses `AttackResourceFile` objects to represent reusable cracking resources such as mask lists, wordlists, rule files, and custom charsets. All uploads go through the CipherSwarm backend, which creates the database record and issues a presigned S3 upload URL. No object in storage should exist without a matching DB entry. Each file includes a declared `resource_type` that drives editor behavior, validation rules, and allowed usage in attacks.

Line-oriented resources (masks, rules, small wordlists) may be edited interactively in the Web UI. Each line is validated individually and exposed via a dedicated endpoint. Larger files must be downloaded, edited offline, and reuploaded.

<!-- section: web-ui-api-resource-browser-implementation-tasks -->

#### 🧩 Implementation Tasks

-   [x] Implement `AttackResourceFile.resource_type` with enum (`mask_list`, `rule_list`, etc.) `task_id:resource.define_enum`
-   [x] Store and expose `line_format`, `line_encoding`, `used_for_modes`, `source` `task_id:resource.augment_metadata`
-   [x] Expose line-count and byte-size metadata for edit gating `task_id:resource.expose_editability_metrics`
-   [x] Validate allowed attack usage based on resource type `task_id:resource.enforce_attack_mode_constraints`
-   [ ] Reject in-browser editing of resources over configured size/line threshold (configurable) `task_id:resource.edit_limit_check`
    -   Add `RESOURCE_EDIT_MAX_SIZE_MB` and `RESOURCE_EDIT_MAX_LINES` settings to `config.py`
-   [ ] Create line-editing endpoints: `task_id:resource.line_api_endpoints`

    -   This will create the line-editing endpoints for the resource. It should be a set of endpoints that allow the user to add, edit, and delete lines in the resource. This is different than the ephemeral attack resources, which are for very small resources that are used directly in attacks. This is an in-editor experience for editing larger, previously uploaded attack resource files. See [Line-Oriented Editing](#line-oriented-editing) for more details.
    -   [ ] `GET /resources/{id}/lines` - This will return a list of lines in the resource. It should be a paginated list of `ResourceLine` objects as described in the [Resource Line Editing](#resource-line-editing) section.
    -   [ ] `POST /resources/{id}/lines` - This will add a new line to the resource. It should take a `line` as a parameter and add it to the resource.
    -   [ ] `PATCH /resources/{id}/lines/{line_id}` - This will update an existing line in the resource. It should take a `line_id` and a `line` as parameters and update the line in the resource.
    -   [ ] `DELETE /resources/{id}/lines/{line_id}` - This will delete an existing line in the resource. It should take a `line_id` as a parameter and delete the line from the resource.

-   [ ] Add model: `ResourceLineValidationError` `task_id:resource.line_validation_model`
    -   This will be a model that is used to validate the lines in the resource. It should be a Pydantic model that validates the lines in the resource. It should be a list of `ResourceLineValidationError` objects conforming to idomatic Pydantic validation error response.
-   [ ] Validate line syntax per type (`mask_list`, `rule_list`) and return structured JSON `task_id:resource.validate_line_content`
    -   This will validate the lines in the resource. It should be a list of `ResourceLineValidationError` objects conforming to idomatic Pydantic validation error response. It should us the same validation functionality as the attack editor line validation using for ephemeral attack resources.
-   [ ] Return `204 No Content` on valid edits, `422` JSON otherwise `task_id:resource.line_edit_response`
-   [ ] Disable editing for `dynamic_word_list` and oversize files `task_id:resource.edit_restrictions`
    -   This will disable editing for `dynamic_word_list` and oversize files. It should be a boolean flag that is used to determine if the resource can be edited.
-   [ ] Support inline preview and batch validation (`?validate=true`) `task_id:resource.line_preview_mode`
-   [ ] Ensure file uploads always create an `
