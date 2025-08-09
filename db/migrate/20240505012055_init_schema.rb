# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Collapsed version of the schema information from the model

# rubocop:disable Rails/CreateTableWithTimestamps
class InitSchema < ActiveRecord::Migration[7.1]
  def down
    raise ActiveRecord::IrreversibleMigration, "The initial migration is not revertable"
  end

  def up
    # These are extensions that must be enabled in order to support this database
    enable_extension "plpgsql"
    create_table "active_storage_attachments" do |t|
      t.string "name", null: false
      t.string "record_type", null: false
      t.bigint "record_id", null: false
      t.bigint "blob_id", null: false
      t.datetime "created_at", null: false
      t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
      t.index %w[record_type record_id name blob_id], name: "index_active_storage_attachments_uniqueness", unique: true
    end
    create_table "active_storage_blobs" do |t|
      t.string "key", null: false
      t.string "filename", null: false
      t.string "content_type"
      t.text "metadata"
      t.string "service_name", null: false
      t.bigint "byte_size", null: false
      t.string "checksum"
      t.datetime "created_at", null: false
      t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
    end
    create_table "active_storage_variant_records" do |t|
      t.bigint "blob_id", null: false
      t.string "variation_digest", null: false
      t.index %w[blob_id variation_digest], name: "index_active_storage_variant_records_uniqueness", unique: true
    end
    create_table "agents" do |t|
      t.text "client_signature", comment: "The signature of the agent"
      t.text "command_parameters", comment: "Parameters to be passed to the agent when it checks in"
      t.boolean "cpu_only", default: false, null: false, comment: "Only use for CPU only tasks"
      t.boolean "ignore_errors", default: false, null: false, comment: "Ignore errors, continue to next task"
      t.boolean "active", default: true, null: false, comment: "Is the agent active"
      t.boolean "trusted", default: false, null: false, comment: "Is the agent trusted to handle sensitive data"
      t.string "last_ipaddress", default: "", comment: "Last known IP address"
      t.datetime "last_seen_at", comment: "Last time the agent checked in"
      t.string "name", default: "", comment: "Name of the agent"
      t.integer "operating_system", default: 0, comment: "Operating system of the agent"
      t.string "token", limit: 24, comment: "Token used to authenticate the agent"
      t.bigint "user_id", comment: "The user that the agent is associated with"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.string "devices", default: [], comment: "Devices that the agent supports", array: true
      t.jsonb "advanced_configuration", default: {}, comment: "Advanced configuration for the agent."
      t.index ["token"], name: "index_agents_on_token", unique: true
      t.index ["user_id"], name: "index_agents_on_user_id"
    end
    create_table "agents_projects", id: false do |t|
      t.bigint "agent_id", null: false
      t.bigint "project_id", null: false
      t.index ["agent_id"], name: "index_agents_projects_on_agent_id"
      t.index ["project_id"], name: "index_agents_projects_on_project_id"
    end
    create_table "attacks" do |t|
      t.string "name", default: "", null: false, comment: "Attack name"
      t.text "description", default: "", comment: "Attack description"
      t.integer "attack_mode", default: 0, null: false, comment: "Hashcat attack mode"
      t.string "mask", comment: "Hashcat mask (e.g. ?a?a?a?a?a?a?a?a)"
      t.boolean "increment_mode", default: false, null: false, comment: "Is the attack using increment mode?"
      t.integer "increment_minimum", comment: "Hashcat increment minimum"
      t.integer "increment_maximum", comment: "Hashcat increment maximum"
      t.boolean "optimized", default: false, null: false, comment: "Is the attack optimized?"
      t.boolean "slow_candidate_generators", default: false, null: false, comment: "Are slow candidate generators enabled?"
      t.integer "workload_profile", default: 3, null: false, comment: "Hashcat workload profile (e.g. 1 for low, 2 for medium, 3 for high, 4 for insane)"
      t.boolean "disable_markov", default: false, null: false, comment: "Is Markov chain disabled?"
      t.boolean "classic_markov", default: false, null: false, comment: "Is classic Markov chain enabled?"
      t.integer "markov_threshold", comment: "Hashcat Markov threshold (e.g. 1000)"
      t.string "type"
      t.string "left_rule", comment: "Left rule"
      t.string "right_rule", comment: "Right rule"
      t.string "custom_charset_1", comment: "Custom charset 1"
      t.string "custom_charset_2", comment: "Custom charset 2"
      t.string "custom_charset_3", comment: "Custom charset 3"
      t.string "custom_charset_4", comment: "Custom charset 4"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.bigint "campaign_id"
      t.integer "priority", default: 0, null: false, comment: "The priority of the attack, higher numbers are higher priority."
      t.string "state"
      t.integer "position", default: 0, null: false, comment: "The position of the attack in the campaign."
      t.datetime "start_time", comment: "The time the attack started."
      t.datetime "end_time", comment: "The time the attack ended."
      t.index ["attack_mode"], name: "index_attacks_on_attack_mode"
      t.index %w[campaign_id position], name: "index_attacks_on_campaign_id_and_position", unique: true
      t.index ["campaign_id"], name: "index_attacks_on_campaign_id"
      t.index ["state"], name: "index_attacks_on_state"
    end
    create_table "attacks_rule_lists", id: false do |t|
      t.bigint "attack_id", null: false
      t.bigint "rule_list_id", null: false
    end
    create_table "attacks_word_lists", id: false do |t|
      t.bigint "attack_id", null: false
      t.bigint "word_list_id", null: false
    end
    create_table "audits" do |t|
      t.integer "auditable_id"
      t.string "auditable_type"
      t.integer "associated_id"
      t.string "associated_type"
      t.integer "user_id"
      t.string "user_type"
      t.string "username"
      t.string "action"
      t.jsonb "audited_changes"
      t.integer "version", default: 0
      t.string "comment"
      t.string "remote_address"
      t.string "request_uuid"
      t.datetime "created_at"
      t.index %w[associated_type associated_id], name: "associated_index"
      t.index %w[auditable_type auditable_id version], name: "auditable_index"
      t.index ["created_at"], name: "index_audits_on_created_at"
      t.index ["request_uuid"], name: "index_audits_on_request_uuid"
      t.index %w[user_id user_type], name: "user_index"
    end
    create_table "campaigns" do |t|
      t.string "name"
      t.bigint "hash_list_id", null: false
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.bigint "project_id", default: 1, null: false
      t.integer "attacks_count", default: 0, null: false
      t.text "description"
      t.index ["hash_list_id"], name: "index_campaigns_on_hash_list_id"
      t.index ["project_id"], name: "index_campaigns_on_project_id"
    end
    create_table "cracker_binaries" do |t|
      t.string "version", null: false, comment: "Version of the cracker binary, e.g. 6.0.0 or 6.0.0-rc1"
      t.boolean "active", default: true, null: false, comment: "Is the cracker binary active?"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.integer "major_version", comment: "The major version of the cracker binary."
      t.integer "minor_version", comment: "The minor version of the cracker binary."
      t.integer "patch_version", comment: "The patch version of the cracker binary."
      t.string "prerelease_version", default: "", comment: "The prerelease version of the cracker binary."
      t.index ["version"], name: "index_cracker_binaries_on_version"
    end
    create_table "cracker_binaries_operating_systems", id: false do |t|
      t.bigint "cracker_binary_id", null: false
      t.bigint "operating_system_id", null: false
      t.index ["cracker_binary_id"], name: "index_cracker_binaries_operating_systems_on_cracker_binary_id"
      t.index ["operating_system_id"], name: "idx_on_operating_system_id_ee00451fea"
    end
    create_table "device_statuses" do |t|
      t.bigint "hashcat_status_id", null: false
      t.integer "device_id", comment: "Device ID"
      t.string "device_name", comment: "Device Name"
      t.string "device_type", comment: "Device Type"
      t.bigint "speed", comment: "Speed "
      t.integer "utilization", comment: "Utilization Percentage"
      t.integer "temperature", comment: "Temperature in Celsius (-1 if not available)"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["hashcat_status_id"], name: "index_device_statuses_on_hashcat_status_id"
    end
    create_table "hash_items" do |t|
      t.boolean "cracked", default: false, null: false, comment: "Is the hash cracked?"
      t.string "plain_text", comment: "Plaintext value of the hash"
      t.datetime "cracked_time", comment: "Time when the hash was cracked"
      t.text "hash_value", null: false, comment: "Hash value"
      t.text "salt", comment: "Salt of the hash"
      t.bigint "hash_list_id", null: false
      t.string "metadata_fields", comment: "Metadata fields of the hash item", array: true
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["cracked"], name: "index_hash_items_on_cracked"
      t.index ["hash_list_id"], name: "index_hash_items_on_hash_list_id"
      t.index %w[hash_value salt hash_list_id], name: "index_hash_items_on_hash_value_and_salt_and_hash_list_id", unique: true
    end
    create_table "hash_lists" do |t|
      t.string "name", null: false, comment: "Name of the hash list"
      t.text "description", comment: "Description of the hash list"
      t.boolean "sensitive", default: false, null: false, comment: "Is the hash list sensitive?"
      t.bigint "project_id", null: false, comment: "Project that the hash list belongs to"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.string "separator", limit: 1, default: ":", null: false, comment: "Separator used in the hash list file to separate the hash from the password or other metadata. Default is \":\"."
      t.integer "metadata_fields_count", default: 0, null: false, comment: "Number of metadata fields in the hash list file. Default is 0."
      t.boolean "processed", default: false, null: false, comment: "Is the hash list processed into hash items?"
      t.boolean "salt", default: false, null: false, comment: "Does the hash list contain a salt?"
      t.bigint "hash_type_id"
      t.integer "hash_items_count", default: 0
      t.index ["hash_type_id"], name: "index_hash_lists_on_hash_type_id"
      t.index ["name"], name: "index_hash_lists_on_name", unique: true
      t.index ["project_id"], name: "index_hash_lists_on_project_id"
    end
    create_table "hash_types" do |t|
      t.integer "hashcat_mode", null: false, comment: "The hashcat mode number"
      t.string "name", null: false, comment: "The name of the hash type"
      t.integer "category", default: 0, null: false, comment: "The category of the hash type"
      t.boolean "built_in", default: false, null: false, comment: "Whether the hash type is built-in"
      t.boolean "enabled", default: true, null: false, comment: "Whether the hash type is enabled"
      t.boolean "is_slow", default: false, null: false, comment: "Whether the hash type is slow"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["hashcat_mode"], name: "index_hash_types_on_hashcat_mode", unique: true
      t.index ["name"], name: "index_hash_types_on_name", unique: true
    end
    create_table "hashcat_benchmarks" do |t|
      t.bigint "agent_id", null: false
      t.integer "hash_type", null: false, comment: "The hashcat hash type."
      t.datetime "benchmark_date", null: false, comment: "The date and time the benchmark was performed."
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.integer "device", comment: "The device used for the benchmark."
      t.float "hash_speed", comment: "The speed of the benchmark. In hashes per second."
      t.float "runtime", comment: "The time taken to complete the benchmark. In seconds."
      t.index %w[agent_id benchmark_date hash_type], name: "idx_on_agent_id_benchmark_date_hash_type_a667ecb9be", unique: true
      t.index ["agent_id"], name: "index_hashcat_benchmarks_on_agent_id"
    end
    create_table "hashcat_guesses" do |t|
      t.bigint "hashcat_status_id", null: false
      t.string "guess_base", comment: "The base value used for the guess (for example, the mask)"
      t.bigint "guess_base_count", comment: "The number of times the base value was used"
      t.bigint "guess_base_offset", comment: "The offset of the base value"
      t.decimal "guess_base_percentage", comment: "The percentage completion of the base value"
      t.string "guess_mod", comment: "The modifier used for the guess (for example, the wordlist)"
      t.bigint "guess_mod_count", comment: "The number of times the modifier was used"
      t.bigint "guess_mod_offset", comment: "The offset of the modifier"
      t.decimal "guess_mod_percentage", comment: "The percentage completion of the modifier"
      t.integer "guess_mode", comment: "The mode used for the guess"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["hashcat_status_id"], name: "index_hashcat_guesses_on_hashcat_status_id"
    end
    create_table "hashcat_statuses" do |t|
      t.bigint "task_id", null: false
      t.text "original_line", comment: "The original line from the hashcat output"
      t.string "session", comment: "The session name"
      t.datetime "time", comment: "The time of the status"
      t.integer "status", comment: "The status code"
      t.string "target", comment: "The target file"
      t.bigint "progress", comment: "The progress in percentage", array: true
      t.bigint "restore_point", comment: "The restore point"
      t.bigint "recovered_hashes", comment: "The number of recovered hashes", array: true
      t.bigint "recovered_salts", comment: "The number of recovered salts", array: true
      t.bigint "rejected", comment: "The number of rejected hashes"
      t.datetime "time_start", comment: "The time the task started"
      t.datetime "estimated_stop", comment: "The estimated time of completion"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["task_id"], name: "index_hashcat_statuses_on_task_id"
    end
    create_table "operating_systems" do |t|
      t.string "name", comment: "Name of the operating system"
      t.string "cracker_command", comment: "Command to run the cracker on this OS"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["name"], name: "index_operating_systems_on_name", unique: true
    end
    create_table "project_users" do |t|
      t.bigint "user_id", null: false
      t.bigint "project_id", null: false
      t.integer "role", default: 0, null: false, comment: "The role of the user in the project."
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["project_id"], name: "index_project_users_on_project_id"
      t.index ["user_id"], name: "index_project_users_on_user_id"
    end
    create_table "projects" do |t|
      t.string "name", limit: 100, null: false, comment: "Name of the project"
      t.text "description", comment: "Description of the project"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["name"], name: "index_projects_on_name", unique: true
    end
    create_table "projects_rule_lists", id: false do |t|
      t.bigint "rule_list_id", null: false
      t.bigint "project_id", null: false
      t.index ["project_id"], name: "index_projects_rule_lists_on_project_id"
      t.index ["rule_list_id"], name: "index_projects_rule_lists_on_rule_list_id"
    end
    create_table "projects_word_lists", id: false do |t|
      t.bigint "project_id", null: false
      t.bigint "word_list_id", null: false
      t.index %w[project_id word_list_id], name: "index_projects_word_lists_on_project_id_and_word_list_id"
      t.index %w[word_list_id project_id], name: "index_projects_word_lists_on_word_list_id_and_project_id"
    end
    create_table "rule_lists" do |t|
      t.string "name", null: false, comment: "Name of the rule list"
      t.text "description", comment: "Description of the rule list"
      t.integer "line_count", default: 0, comment: "Number of lines in the rule list"
      t.boolean "sensitive", default: false, null: false, comment: "Sensitive rule list"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.boolean "processed", default: false, null: false
      t.index ["name"], name: "index_rule_lists_on_name", unique: true
    end
    create_table "tasks" do |t|
      t.bigint "attack_id", null: false, comment: "The attack that the task is associated with."
      t.bigint "agent_id", comment: "The agent that the task is assigned to, if any."
      t.datetime "start_date", comment: "The date and time that the task was started."
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.datetime "activity_timestamp", comment: "The timestamp of the last activity on the task"
      t.integer "keyspace_limit", default: 0, comment: "The maximum number of keyspace values to process."
      t.integer "keyspace_offset", default: 0, comment: "The starting keyspace offset."
      t.string "state", default: "pending", null: false
      t.index ["agent_id"], name: "index_tasks_on_agent_id"
      t.index ["attack_id"], name: "index_tasks_on_attack_id"
      t.index ["state"], name: "index_tasks_on_state"
    end
    create_table "users" do |t|
      t.string "email", limit: 50, default: "", null: false
      t.string "encrypted_password", default: "", null: false
      t.string "reset_password_token"
      t.datetime "reset_password_sent_at"
      t.datetime "remember_created_at"
      t.integer "sign_in_count", default: 0, null: false
      t.datetime "current_sign_in_at"
      t.datetime "last_sign_in_at"
      t.string "current_sign_in_ip"
      t.string "last_sign_in_ip"
      t.integer "failed_attempts", default: 0, null: false
      t.string "unlock_token"
      t.datetime "locked_at"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.string "name", default: -> { "md5((random())::text)" }, null: false, comment: "Unique username. Used for login."
      t.integer "role", default: 0, comment: "The role of the user, either basic or admin"
      t.index ["email"], name: "index_users_on_email", unique: true
      t.index ["name"], name: "index_users_on_name", unique: true
      t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
      t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
    end
    create_table "word_lists" do |t|
      t.string "name", comment: "Name of the word list"
      t.text "description", comment: "Description of the word list"
      t.integer "line_count", comment: "Number of lines in the word list"
      t.boolean "sensitive", default: false, null: false, comment: "Is the word list sensitive?"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.boolean "processed", default: false, null: false
      t.index ["name"], name: "index_word_lists_on_name", unique: true
      t.index ["processed"], name: "index_word_lists_on_processed"
    end
    add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
    add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
    add_foreign_key "attacks", "campaigns"
    add_foreign_key "campaigns", "hash_lists"
    add_foreign_key "campaigns", "projects"
    add_foreign_key "device_statuses", "hashcat_statuses"
    add_foreign_key "hash_items", "hash_lists"
    add_foreign_key "hash_lists", "hash_types"
    add_foreign_key "hash_lists", "projects"
    add_foreign_key "hashcat_benchmarks", "agents"
    add_foreign_key "hashcat_guesses", "hashcat_statuses"
    add_foreign_key "hashcat_statuses", "tasks"
    add_foreign_key "project_users", "projects"
    add_foreign_key "project_users", "users"
    add_foreign_key "tasks", "agents"
    add_foreign_key "tasks", "attacks"
  end
end
