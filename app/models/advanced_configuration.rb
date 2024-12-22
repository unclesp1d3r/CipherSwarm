# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# AdvancedConfiguration is a class that includes the StoreModel::Model module
# and defines attributes for advanced configurations. This class enables
# assigning and managing specific advanced settings typically used in custom
# environments.
#
# === Attributes
#
# - *agent_update_interval* - An integer attribute that sets the interval
#   for agent updates. The default value is a random number between 5 and 15
#   inclusive.
# - *use_native_hashcat* - A boolean attribute that indicates whether the
#   native hashcat will be used. The default value is false.
# - *backend_device* - A string attribute specifying the backend device
#   configuration.
# - *opencl_devices* - A string attribute specifying OpenCL devices to use.
# - *enable_additional_hash_types* - A boolean attribute that enables
#   additional hash types. The default value is false.
#
# This class is useful for defining and managing configuration parameters
# that may vary based on different configurations or specific use cases.
class AdvancedConfiguration
  include StoreModel::Model
  attribute :agent_update_interval, :integer, default: -> { rand(5..15) }
  attribute :use_native_hashcat, :boolean, default: false
  attribute :backend_device, :string
  attribute :opencl_devices, :string
  attribute :enable_additional_hash_types, :boolean, default: false
end
