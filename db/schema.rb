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

ActiveRecord::Schema[7.1].define(version: 2024_03_01_025327) do
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
    t.boolean "allow_device_to_change_name", default: true, comment: "Allow the device to change its name to match the agent hostname"
    t.bigint "user_id", comment: "The user that the agent is associated with"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token"], name: "index_agents_on_token", unique: true
    t.index ["user_id"], name: "index_agents_on_user_id"
  end

  create_table "agents_projects", id: false, force: :cascade do |t|
    t.bigint "agent_id", null: false
    t.bigint "project_id", null: false
    t.index ["agent_id"], name: "index_agents_projects_on_agent_id"
    t.index ["project_id"], name: "index_agents_projects_on_project_id"
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

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "project_users", "projects"
  add_foreign_key "project_users", "users"
end
