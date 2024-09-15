# frozen_string_literal: true

#
# The AdvancedConfiguration class is a model that includes the StoreModel::Model module.
# It defines several attributes with their respective types and default values.
#
# Attributes:
# - agent_update_interval: Integer, default value is a random number between 5 and 15.
# - use_native_hashcat: Boolean, default value is false.
# - backend_device: String, no default value.
# - opencl_devices: String, no default value.
# - enable_additional_hash_types: Boolean, default value is false.
class AdvancedConfiguration
  include StoreModel::Model
  attribute :agent_update_interval, :integer, default: -> { rand(5..15) }
  attribute :use_native_hashcat, :boolean, default: false
  attribute :backend_device, :string
  attribute :opencl_devices, :string
  attribute :enable_additional_hash_types, :boolean, default: false
end
