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

ActiveRecord::Schema[8.0].define(version: 2025_07_15_132801) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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

  create_table "credit_transactions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "transaction_type", null: false
    t.integer "amount", null: false
    t.bigint "presentation_id"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["presentation_id"], name: "index_credit_transactions_on_presentation_id"
    t.index ["transaction_type"], name: "index_credit_transactions_on_transaction_type"
    t.index ["user_id", "created_at"], name: "index_credit_transactions_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_credit_transactions_on_user_id"
  end

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
    t.string "duration"
    t.string "difficulty"
    t.string "image"
    t.boolean "published", default: false
    t.decimal "rating", precision: 3, scale: 2
    t.integer "review_count", default: 0
    t.text "whiskey_recommendations"
    t.text "tasting_notes"
    t.text "nose_notes"
    t.text "palate_notes"
    t.text "finish_notes"
    t.text "body_notes"
    t.jsonb "whiskey_recommendations_json", default: []
    t.text "what_youll_learn"
    t.text "slides_preview"
    t.index ["author_id"], name: "index_presentations_on_author_id"
    t.index ["category"], name: "index_presentations_on_category"
    t.index ["price"], name: "index_presentations_on_price"
    t.index ["title"], name: "index_presentations_on_title"
    t.index ["whiskey_recommendations_json"], name: "index_presentations_on_whiskey_recommendations_json", using: :gin
  end

  create_table "societies", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "location"
    t.bigint "creator_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_private"
    t.string "banner_position", default: "center center"
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

  create_table "tags", force: :cascade do |t|
    t.string "name", null: false
    t.string "color", default: "#3B82F6", null: false
    t.string "category", default: "whiskey"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_tags_on_category"
    t.index ["name"], name: "index_tags_on_name", unique: true
  end

  create_table "user_presentations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "presentation_id", null: false
    t.string "purchase_type", default: "credit", null: false
    t.datetime "purchased_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "purchase_price", precision: 10, scale: 2
    t.string "stripe_payment_intent_id"
    t.index ["presentation_id"], name: "index_user_presentations_on_presentation_id"
    t.index ["purchase_type"], name: "index_user_presentations_on_purchase_type"
    t.index ["user_id"], name: "index_user_presentations_on_user_id"
  end

  create_table "user_tags", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tag_id"], name: "index_user_tags_on_tag_id"
    t.index ["user_id", "tag_id"], name: "index_user_tags_on_user_id_and_tag_id", unique: true
    t.index ["user_id"], name: "index_user_tags_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "provider"
    t.string "uid"
    t.string "first_name"
    t.string "last_name"
    t.text "bio"
    t.string "unconfirmed_email"
    t.string "email_change_token"
    t.datetime "email_change_token_expires_at"
    t.string "otp_secret_key"
    t.boolean "otp_enabled", default: false
    t.text "backup_codes"
    t.boolean "password_set_manually", default: false, null: false
    t.string "stripe_customer_id"
    t.string "stripe_subscription_id"
    t.string "subscription_status"
    t.string "subscription_plan"
    t.datetime "subscription_ends_at"
    t.text "whiskey_shelf"
    t.integer "credits", default: 0, null: false
    t.boolean "cancel_at_period_end", default: false
    t.boolean "is_admin", default: false, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["is_admin"], name: "index_users_on_is_admin"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "credit_transactions", "presentations"
  add_foreign_key "credit_transactions", "users"
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
  add_foreign_key "user_presentations", "presentations"
  add_foreign_key "user_presentations", "users"
  add_foreign_key "user_tags", "tags"
  add_foreign_key "user_tags", "users"
end
