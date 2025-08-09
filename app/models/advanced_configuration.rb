# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Manages advanced configuration settings for agents and hashcat.
#
# @attributes
# - agent_update_interval: interval for updates (default: random 5-15)
# - use_native_hashcat: use native hashcat binary (default: false)
# - backend_device: backend device configuration
# - opencl_devices: OpenCL devices specification
# - enable_additional_hash_types: enable extra hash types (default: false)
#
# @includes
# - StoreModel::Model: enables attribute management
#
class AdvancedConfiguration
  include StoreModel::Model
  attribute :agent_update_interval, :integer, default: -> { rand(5..15) }
  attribute :use_native_hashcat, :boolean, default: false
  attribute :backend_device, :string
  attribute :opencl_devices, :string
  attribute :enable_additional_hash_types, :boolean, default: false
end
