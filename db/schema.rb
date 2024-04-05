# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2024_04_02_225538) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
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

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "agents", force: :cascade do |t|
    t.text "client_signature", comment: "The signature of the agent"
    t.text "command_parameters", comment: "Parameters to be passed to the agent when it checks in"
    t.boolean "cpu_only", default: false, comment: "Only use for CPU only tasks"
    t.boolean "ignore_errors", default: false, comment: "Ignore errors, continue to next task"
    t.boolean "active", default: true, comment: "Is the agent active"
    t.boolean "trusted", default: false, comment: "Is the agent trusted to handle sensitive data"
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

  create_table "agents_projects", id: false, force: :cascade do |t|
    t.bigint "agent_id", null: false
    t.bigint "project_id", null: false
    t.index ["agent_id"], name: "index_agents_projects_on_agent_id"
    t.index ["project_id"], name: "index_agents_projects_on_project_id"
  end

  create_table "audits", force: :cascade do |t|
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
    t.index ["associated_type", "associated_id"], name: "associated_index"
    t.index ["auditable_type", "auditable_id", "version"], name: "auditable_index"
    t.index ["created_at"], name: "index_audits_on_created_at"
    t.index ["request_uuid"], name: "index_audits_on_request_uuid"
    t.index ["user_id", "user_type"], name: "user_index"
  end

  create_table "campaigns", force: :cascade do |t|
    t.string "name"
    t.bigint "hash_list_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "project_id"
    t.index ["hash_list_id"], name: "index_campaigns_on_hash_list_id"
    t.index ["project_id"], name: "index_campaigns_on_project_id"
  end

  create_table "cracker_binaries", force: :cascade do |t|
    t.string "version", null: false, comment: "Version of the cracker binary, e.g. 6.0.0 or 6.0.0-rc1"
    t.boolean "active", default: true, comment: "Is the cracker binary active?"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "major_version", comment: "The major version of the cracker binary."
    t.integer "minor_version", comment: "The minor version of the cracker binary."
    t.integer "patch_version", comment: "The patch version of the cracker binary."
    t.string "prerelease_version", default: "", comment: "The prerelease version of the cracker binary."
    t.index ["version"], name: "index_cracker_binaries_on_version"
  end

  create_table "cracker_binaries_operating_systems", id: false, force: :cascade do |t|
    t.bigint "cracker_binary_id", null: false
    t.bigint "operating_system_id", null: false
    t.index ["cracker_binary_id"], name: "index_cracker_binaries_operating_systems_on_cracker_binary_id"
    t.index ["operating_system_id"], name: "idx_on_operating_system_id_ee00451fea"
  end

  create_table "device_statuses", force: :cascade do |t|
    t.bigint "hashcat_status_id", null: false
    t.integer "device_id", comment: "Device ID"
    t.string "device_name", comment: "Device Name"
    t.string "device_type", comment: "Device Type"
    t.integer "speed", comment: "Speed "
    t.integer "utilization", comment: "Utilization Percentage"
    t.integer "temperature", comment: "Temperature in Celsius (-1 if not available)"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["hashcat_status_id"], name: "index_device_statuses_on_hashcat_status_id"
  end

  create_table "hash_items", force: :cascade do |t|
    t.boolean "cracked", default: false, comment: "Is the hash cracked?"
    t.string "plain_text", comment: "Plaintext value of the hash"
    t.datetime "cracked_time", comment: "Time when the hash was cracked"
    t.text "hash_value", null: false, comment: "Hash value"
    t.text "salt", comment: "Salt of the hash"
    t.bigint "hash_list_id", null: false
    t.string "metadata_fields", comment: "Metadata fields of the hash item", array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["hash_list_id"], name: "index_hash_items_on_hash_list_id"
    t.index ["hash_value", "salt", "hash_list_id"], name: "index_hash_items_on_hash_value_and_salt_and_hash_list_id", unique: true
  end

  create_table "hash_lists", force: :cascade do |t|
    t.string "name", null: false, comment: "Name of the hash list"
    t.text "description", comment: "Description of the hash list"
    t.boolean "sensitive", default: false, comment: "Is the hash list sensitive?"
    t.integer "hash_mode", null: false, comment: "Hash mode of the hash list (hashcat mode)"
    t.bigint "project_id", null: false, comment: "Project that the hash list belongs to"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "separator", limit: 1, default: ":", null: false, comment: "Separator used in the hash list file to separate the hash from the password or other metadata. Default is \":\"."
    t.integer "metadata_fields_count", default: 0, null: false, comment: "Number of metadata fields in the hash list file. Default is 0."
    t.boolean "processed", default: false, comment: "Is the hash list processed into hash items?"
    t.boolean "salt", default: false, comment: "Does the hash list contain a salt?"
    t.index ["hash_mode"], name: "index_hash_lists_on_hash_mode"
    t.index ["name"], name: "index_hash_lists_on_name", unique: true
    t.index ["project_id"], name: "index_hash_lists_on_project_id"
  end

  create_table "hashcat_benchmarks", force: :cascade do |t|
    t.bigint "agent_id", null: false
    t.integer "hash_type", null: false, comment: "The hashcat hash type."
    t.datetime "benchmark_date", null: false, comment: "The date and time the benchmark was performed."
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "device", comment: "The device used for the benchmark."
    t.float "hash_speed", comment: "The speed of the benchmark. In hashes per second."
    t.bigint "runtime", comment: "The time taken to complete the benchmark. In milliseconds."
    t.index ["agent_id", "benchmark_date", "hash_type"], name: "idx_on_agent_id_benchmark_date_hash_type_a667ecb9be", unique: true
    t.index ["agent_id"], name: "index_hashcat_benchmarks_on_agent_id"
  end

  create_table "hashcat_guesses", force: :cascade do |t|
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

  create_table "hashcat_statuses", force: :cascade do |t|
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

  create_table "operating_systems", force: :cascade do |t|
    t.string "name", comment: "Name of the operating system"
    t.string "cracker_command", comment: "Command to run the cracker on this OS"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_operating_systems_on_name", unique: true
  end

  create_table "operations", force: :cascade do |t|
    t.string "name", default: "", null: false, comment: "Attack name"
    t.text "description", default: "", comment: "Attack description"
    t.integer "attack_mode", default: 0, null: false, comment: "Hashcat attack mode"
    t.string "mask", default: "", comment: "Hashcat mask (e.g. ?a?a?a?a?a?a?a?a)"
    t.boolean "increment_mode", default: false, null: false, comment: "Is the attack using increment mode?"
    t.integer "increment_minimum", default: 0, comment: "Hashcat increment minimum"
    t.integer "increment_maximum", default: 0, comment: "Hashcat increment maximum"
    t.boolean "optimized", default: false, null: false, comment: "Is the attack optimized?"
    t.boolean "slow_candidate_generators", default: false, null: false, comment: "Are slow candidate generators enabled?"
    t.integer "workload_profile", default: 3, null: false, comment: "Hashcat workload profile (e.g. 1 for low, 2 for medium, 3 for high, 4 for insane)"
    t.boolean "disable_markov", default: false, null: false, comment: "Is Markov chain disabled?"
    t.boolean "classic_markov", default: false, null: false, comment: "Is classic Markov chain enabled?"
    t.integer "markov_threshold", default: 0, comment: "Hashcat Markov threshold (e.g. 1000)"
    t.string "type"
    t.string "left_rule", default: "", comment: "Left rule"
    t.string "right_rule", default: "", comment: "Right rule"
    t.string "custom_charset_1", default: "", comment: "Custom charset 1"
    t.string "custom_charset_2", default: "", comment: "Custom charset 2"
    t.string "custom_charset_3", default: "", comment: "Custom charset 3"
    t.string "custom_charset_4", default: "", comment: "Custom charset 4"
    t.bigint "campaign_id"
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "updated_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.integer "priority", default: 0, null: false, comment: "The priority of the attack, higher numbers are higher priority."
    t.string "state"
    t.index ["attack_mode"], name: "index_operations_on_attack_mode"
    t.index ["campaign_id"], name: "index_operations_on_campaign_id"
    t.index ["state"], name: "index_operations_on_state"
  end

  create_table "operations_rule_lists", id: false, force: :cascade do |t|
    t.bigint "operation_id", null: false
    t.bigint "rule_list_id", null: false
    t.index ["operation_id", "rule_list_id"], name: "index_operations_rule_lists_on_operation_id_and_rule_list_id"
    t.index ["rule_list_id", "operation_id"], name: "index_operations_rule_lists_on_rule_list_id_and_operation_id"
  end

  create_table "operations_word_lists", id: false, force: :cascade do |t|
    t.bigint "operation_id", null: false
    t.bigint "word_list_id", null: false
    t.index ["operation_id"], name: "index_operations_word_lists_on_operation_id"
    t.index ["word_list_id"], name: "index_operations_word_lists_on_word_list_id"
  end

  create_table "project_users", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "project_id", null: false
    t.integer "role", default: 0, null: false, comment: "The role of the user in the project."
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_project_users_on_project_id"
    t.index ["user_id"], name: "index_project_users_on_user_id"
  end

  create_table "projects", force: :cascade do |t|
    t.string "name", limit: 100, null: false, comment: "Name of the project"
    t.text "description", comment: "Description of the project"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_projects_on_name", unique: true
  end

  create_table "projects_rule_lists", id: false, force: :cascade do |t|
    t.bigint "rule_list_id", null: false
    t.bigint "project_id", null: false
    t.index ["project_id"], name: "index_projects_rule_lists_on_project_id"
    t.index ["rule_list_id"], name: "index_projects_rule_lists_on_rule_list_id"
  end

  create_table "projects_word_lists", id: false, force: :cascade do |t|
    t.bigint "project_id", null: false
    t.bigint "word_list_id", null: false
    t.index ["project_id", "word_list_id"], name: "index_projects_word_lists_on_project_id_and_word_list_id"
    t.index ["word_list_id", "project_id"], name: "index_projects_word_lists_on_word_list_id_and_project_id"
  end

  create_table "rule_lists", force: :cascade do |t|
    t.string "name", null: false, comment: "Name of the rule list"
    t.text "description", comment: "Description of the rule list"
    t.integer "line_count", default: 0, comment: "Number of lines in the rule list"
    t.boolean "sensitive", default: false, comment: "Sensitive rule list"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "processed", default: false
    t.index ["name"], name: "index_rule_lists_on_name", unique: true
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "tasks", force: :cascade do |t|
    t.bigint "operation_id", null: false, comment: "The attack that the task is associated with."
    t.bigint "agent_id", comment: "The agent that the task is assigned to, if any."
    t.datetime "start_date", null: false, comment: "The date and time that the task was started."
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "activity_timestamp", comment: "The timestamp of the last activity on the task"
    t.integer "keyspace_limit", default: 0, comment: "The maximum number of keyspace values to process."
    t.integer "keyspace_offset", default: 0, comment: "The starting keyspace offset."
    t.string "state", default: "pending", null: false
    t.index ["agent_id"], name: "index_tasks_on_agent_id"
    t.index ["operation_id"], name: "index_tasks_on_operation_id"
    t.index ["state"], name: "index_tasks_on_state"
  end

  create_table "users", force: :cascade do |t|
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
    t.string "name", null: false, comment: "Unique username. Used for login."
    t.integer "role", default: 0, comment: "The role of the user, either basic or admin"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["name"], name: "index_users_on_name", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  create_table "word_lists", force: :cascade do |t|
    t.string "name", comment: "Name of the word list"
    t.text "description", comment: "Description of the word list"
    t.integer "line_count", comment: "Number of lines in the word list"
    t.boolean "sensitive", comment: "Is the word list sensitive?"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "processed", default: false
    t.index ["name"], name: "index_word_lists_on_name", unique: true
    t.index ["processed"], name: "index_word_lists_on_processed"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "campaigns", "hash_lists"
  add_foreign_key "campaigns", "projects"
  add_foreign_key "device_statuses", "hashcat_statuses"
  add_foreign_key "hash_items", "hash_lists"
  add_foreign_key "hash_lists", "projects"
  add_foreign_key "hashcat_benchmarks", "agents"
  add_foreign_key "hashcat_guesses", "hashcat_statuses"
  add_foreign_key "hashcat_statuses", "tasks"
  add_foreign_key "operations", "campaigns"
  add_foreign_key "project_users", "projects"
  add_foreign_key "project_users", "users"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "tasks", "agents"
  add_foreign_key "tasks", "operations"
end
