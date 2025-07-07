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

ActiveRecord::Schema[8.0].define(version: 2025_07_07_001737) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "event_rsvps", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "event_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_event_rsvps_on_event_id"
    t.index ["status"], name: "index_event_rsvps_on_status"
    t.index ["user_id", "event_id"], name: "index_event_rsvps_on_user_id_and_event_id", unique: true
    t.index ["user_id"], name: "index_event_rsvps_on_user_id"
  end

  create_table "events", force: :cascade do |t|
    t.string "title", null: false
    t.text "description"
    t.string "location"
    t.datetime "start_time", null: false
    t.datetime "end_time"
    t.bigint "society_id", null: false
    t.bigint "organizer_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["location"], name: "index_events_on_location"
    t.index ["organizer_id"], name: "index_events_on_organizer_id"
    t.index ["society_id", "start_time"], name: "index_events_on_society_id_and_start_time"
    t.index ["society_id"], name: "index_events_on_society_id"
    t.index ["start_time"], name: "index_events_on_start_time"
    t.index ["title"], name: "index_events_on_title"
  end

  create_table "forums", force: :cascade do |t|
    t.bigint "society_id", null: false
    t.string "name"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["society_id"], name: "index_forums_on_society_id"
  end

  create_table "presentations", force: :cascade do |t|
    t.string "title", null: false
    t.text "description"
    t.text "content"
    t.bigint "author_id", null: false
    t.decimal "price", precision: 10, scale: 2, default: "0.0"
    t.string "category"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_presentations_on_author_id"
    t.index ["category"], name: "index_presentations_on_category"
    t.index ["price"], name: "index_presentations_on_price"
    t.index ["title"], name: "index_presentations_on_title"
  end

  create_table "societies", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "location"
    t.bigint "creator_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_private"
    t.index ["creator_id"], name: "index_societies_on_creator_id"
    t.index ["location"], name: "index_societies_on_location"
    t.index ["name"], name: "index_societies_on_name"
  end

  create_table "society_applications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "society_id", null: false
    t.text "message"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["society_id"], name: "index_society_applications_on_society_id"
    t.index ["user_id"], name: "index_society_applications_on_user_id"
  end

  create_table "society_memberships", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "society_id", null: false
    t.string "role", default: "member", null: false
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["role"], name: "index_society_memberships_on_role"
    t.index ["society_id"], name: "index_society_memberships_on_society_id"
    t.index ["status"], name: "index_society_memberships_on_status"
    t.index ["user_id", "society_id"], name: "index_society_memberships_on_user_id_and_society_id", unique: true
    t.index ["user_id"], name: "index_society_memberships_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "event_rsvps", "events"
  add_foreign_key "event_rsvps", "users"
  add_foreign_key "events", "societies"
  add_foreign_key "events", "users", column: "organizer_id"
  add_foreign_key "forums", "societies"
  add_foreign_key "presentations", "users", column: "author_id"
  add_foreign_key "societies", "users", column: "creator_id"
  add_foreign_key "society_applications", "societies"
  add_foreign_key "society_applications", "users"
  add_foreign_key "society_memberships", "societies"
  add_foreign_key "society_memberships", "users"
end
