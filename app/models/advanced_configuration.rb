# frozen_string_literal: true

class AdvancedConfiguration
  include StoreModel::Model
  attribute :agent_update_interval, :integer, default: -> { rand(5..15) }
  attribute :use_native_hashcat, :boolean, default: false
  attribute :backend_device, :string
end
