class CreateAgents < ActiveRecord::Migration[7.1]
  def change
    create_table :agents do |t|
      t.text :client_signature, comment: "The signature of the agent"
      t.text :command_parameters, comment: "Parameters to be passed to the agent when it checks in"
      t.boolean :cpu_only, default: false, comment: "Only use for CPU only tasks"
      t.boolean :ignore_errors, default: false, comment: "Ignore errors, continue to next task"
      t.boolean :active, default: true, comment: "Is the agent active"
      t.boolean :trusted, default: false, comment: "Is the agent trusted to handle sensitive data"
      t.string :last_ipaddress, default: '', comment: "Last known IP address"
      t.datetime :last_seen_at, comment: "Last time the agent checked in"
      t.string :name, default: '', comment: "Name of the agent"
      t.integer :operating_system, default: 0, comment: "Operating system of the agent"
      t.string :token, limit: 24, comment: "Token used to authenticate the agent"
      t.boolean :allow_device_to_change_name, default: true, comment: "Allow the device to change its name to match the agent hostname"
      t.belongs_to :user, comment: "The user that the agent is associated with"

      t.timestamps
    end

    add_index :agents, :token, unique: true
  end
end
