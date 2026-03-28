# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Agent::Broadcasting provides Turbo Stream broadcasting functionality for Agent models.
#
# This concern encapsulates methods for broadcasting granular UI updates via Turbo Streams
# when agent data changes. Instead of full-page refreshes, it broadcasts targeted partial
# replacements to specific DOM elements (index cards, detail tabs) so the UI stays in sync
# without resetting active tab state.
#
# REASONING:
# - Extracted broadcasting logic from Agent model to improve code organization and reduce model size.
# - Broadcasting is a cohesive set of 5 methods + 1 constant + 1 callback, all related to
#   Turbo Stream UI updates triggered by agent data changes.
# Alternatives Considered:
# - Keep methods in Agent model: Viable (model was 417 lines), but broadcasting forms a clear
#   behavioral unit matching the existing Agent::Benchmarking extraction pattern.
# - Use a service object: Wrong abstraction — broadcasts are tightly coupled to model lifecycle
#   callbacks and require access to ActiveRecord dirty tracking (saved_change_to_*).
# - Use a decorator: Adds indirection without benefit since methods must be callable as callbacks.
# Decision:
# - ActiveSupport::Concern provides clean extraction with access to Agent's dirty tracking,
#   associations, and ActionView helpers. Follows the established Agent::Benchmarking pattern.
# Performance Implications:
# - None — code is relocated, not changed. No additional queries or method dispatch overhead.
# Future Considerations:
# - If new broadcast targets are added (e.g., agent task list, error detail panel), they belong
#   in this concern to keep all broadcasting logic centralized.
# - broadcast_index_errors is called externally from AgentError#after_create_commit (not via
#   the after_update_commit callback). Any new external broadcast methods should document
#   their call contract similarly.
#
# @note broadcast_index_errors is NOT triggered by the after_update_commit callback.
#   It is called from AgentError#after_create_commit (agent_error.rb:68) to update the
#   error count on index cards when a new error is created. This external call contract
#   must be preserved by any model that includes this concern.
#
# @example Basic usage
#   agent.broadcast_index_state      # replaces state pill on index cards (after state change)
#   agent.broadcast_index_errors     # replaces error count on index cards (called from AgentError)
#   agent.broadcast_index_last_seen  # replaces last-seen value on index cards
#   agent.broadcast_tab_updates      # replaces overview/configuration/capabilities tab panels
#
module Agent::Broadcasting
  extend ActiveSupport::Concern

  # Fields whose changes should trigger an overview tab broadcast.
  # These are the metrics shown on the overview tab (state, activity, performance).
  OVERVIEW_BROADCAST_FIELDS = %w[
    state current_activity current_hash_rate current_temperature current_utilization
  ].freeze

  # Fields whose changes should trigger a configuration tab broadcast.
  CONFIGURATION_BROADCAST_FIELDS = %w[
    enabled client_signature last_ipaddress advanced_configuration
    custom_label operating_system user_id
  ].freeze

  included do
    # Broadcast tab-specific updates instead of full page refresh.
    # This prevents resetting the active tab state when agent data changes.
    after_update_commit :broadcast_tab_updates, :broadcast_index_state, :broadcast_index_last_seen
  end

  # Replaces just the state pill on index cards when the agent's state transitions.
  # Index cards subscribe to the bare agent stream via turbo_stream_from(agent).
  # Only fires on state transitions to avoid excessive updates from heartbeats.
  def broadcast_index_state
    return unless saved_change_to_state?

    broadcast_replace_later_to self,
      target: ActionView::RecordIdentifier.dom_id(self, :index_state),
      partial: "agents/index_state",
      locals: { agent: self }
  end

  # Replaces just the error count on index cards when a new AgentError is created.
  #
  # @note Called from AgentError#after_create_commit to keep the broadcast contract on Agent,
  #   matching the pattern of broadcast_index_state and broadcast_index_last_seen.
  #   This method is NOT triggered by the after_update_commit callback.
  def broadcast_index_errors
    broadcast_replace_later_to self,
      target: ActionView::RecordIdentifier.dom_id(self, :index_errors),
      partial: "agents/index_errors",
      locals: { agent: self }
  end

  # Replaces just the "Last Seen" value on index cards when last_seen_at changes.
  def broadcast_index_last_seen
    return unless saved_change_to_last_seen_at?

    broadcast_replace_later_to self,
      target: ActionView::RecordIdentifier.dom_id(self, :index_last_seen),
      partial: "agents/index_last_seen",
      locals: { agent: self }
  end

  # Broadcasts updates to individual tab streams instead of the root agent stream.
  # This allows each tab panel to update independently without affecting the active tab state.
  #
  # Overview: only when metrics/state change (not on every heartbeat touch).
  # Configuration: only when config-relevant fields change.
  # Capabilities: only when state changes (benchmark data arrives via state transitions).
  def broadcast_tab_updates
    if saved_changes.keys.intersect?(OVERVIEW_BROADCAST_FIELDS)
      broadcast_replace_later_to [self, :overview],
        target: ActionView::RecordIdentifier.dom_id(self, :overview),
        partial: "agents/overview_tab",
        locals: { agent: self }
    end

    if saved_changes.keys.intersect?(CONFIGURATION_BROADCAST_FIELDS)
      broadcast_replace_later_to [self, :configuration],
        target: ActionView::RecordIdentifier.dom_id(self, :configuration),
        partial: "agents/configuration_tab",
        locals: { agent: self }
    end

    return unless saved_change_to_state?

    broadcast_replace_later_to [self, :capabilities],
      target: ActionView::RecordIdentifier.dom_id(self, :capabilities),
      partial: "agents/capabilities_tab",
      locals: { agent: self }
  end
end
