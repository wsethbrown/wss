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

ActiveRecord::Schema[8.0].define(version: 2026_07_23_180000) do
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

  create_table "activity_logs", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "trackable_type"
    t.bigint "trackable_id"
    t.string "activity_type", null: false
    t.jsonb "metadata", default: {}
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["activity_type"], name: "index_activity_logs_on_activity_type"
    t.index ["created_at"], name: "index_activity_logs_on_created_at"
    t.index ["trackable_type", "trackable_id"], name: "index_activity_logs_on_trackable"
    t.index ["user_id", "created_at"], name: "index_activity_logs_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_activity_logs_on_user_id"
  end

  create_table "bottle_edits", force: :cascade do |t|
    t.bigint "bottle_id", null: false
    t.bigint "user_id", null: false
    t.string "field", null: false
    t.string "proposed_value", null: false
    t.string "status", default: "pending", null: false
    t.datetime "applied_at"
    t.bigint "applied_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["applied_by_id"], name: "index_bottle_edits_on_applied_by_id"
    t.index ["bottle_id", "field", "status"], name: "index_bottle_edits_on_bottle_field_status"
    t.index ["bottle_id", "field", "user_id"], name: "index_bottle_edits_on_live_proposal", unique: true, where: "((status)::text = 'pending'::text)"
    t.index ["bottle_id"], name: "index_bottle_edits_on_bottle_id"
    t.index ["user_id"], name: "index_bottle_edits_on_user_id"
  end

  create_table "bottles", force: :cascade do |t|
    t.string "name", null: false
    t.string "distillery"
    t.string "region"
    t.string "style"
    t.decimal "abv", precision: 4, scale: 1
    t.string "slug", null: false
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((name)::text), lower((COALESCE(distillery, ''::character varying))::text)", name: "index_bottles_on_lower_name_distillery"
    t.index ["created_by_id"], name: "index_bottles_on_created_by_id"
    t.index ["slug"], name: "index_bottles_on_slug", unique: true
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

  create_table "download_logs", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "presentation_id", null: false
    t.string "file_type", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "downloaded_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["downloaded_at"], name: "index_download_logs_on_downloaded_at"
    t.index ["presentation_id", "file_type"], name: "index_download_logs_on_presentation_id_and_file_type"
    t.index ["presentation_id"], name: "index_download_logs_on_presentation_id"
    t.index ["user_id", "downloaded_at"], name: "index_download_logs_on_user_id_and_downloaded_at"
    t.index ["user_id"], name: "index_download_logs_on_user_id"
  end

  create_table "event_bottles", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.bigint "bottle_id", null: false
    t.integer "position", null: false
    t.string "label"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "notes"
    t.index ["bottle_id"], name: "index_event_bottles_on_bottle_id"
    t.index ["event_id", "bottle_id"], name: "index_event_bottles_on_event_id_and_bottle_id", unique: true
    t.index ["event_id", "position"], name: "index_event_bottles_on_event_id_and_position"
    t.index ["event_id"], name: "index_event_bottles_on_event_id"
  end

  create_table "event_comments", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.bigint "user_id", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id", "created_at"], name: "index_event_comments_on_event_id_and_created_at"
    t.index ["event_id"], name: "index_event_comments_on_event_id"
    t.index ["user_id"], name: "index_event_comments_on_user_id"
  end

  create_table "event_rsvps", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "event_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "note"
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
    t.boolean "pours_hidden_until_complete", default: false, null: false
    t.bigint "host_id"
    t.bigint "presentation_id"
    t.string "host_name"
    t.index ["host_id"], name: "index_events_on_host_id"
    t.index ["location"], name: "index_events_on_location"
    t.index ["organizer_id"], name: "index_events_on_organizer_id"
    t.index ["presentation_id"], name: "index_events_on_presentation_id"
    t.index ["society_id", "start_time"], name: "index_events_on_society_id_and_start_time"
    t.index ["society_id"], name: "index_events_on_society_id"
    t.index ["start_time"], name: "index_events_on_start_time"
    t.index ["title"], name: "index_events_on_title"
  end

  create_table "favorites", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "favoritable_type", null: false
    t.bigint "favoritable_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["favoritable_type", "favoritable_id"], name: "index_favorites_on_favoritable"
    t.index ["user_id", "favoritable_type", "favoritable_id"], name: "index_favorites_on_user_and_favoritable", unique: true
    t.index ["user_id"], name: "index_favorites_on_user_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "actor_id"
    t.string "notifiable_type"
    t.bigint "notifiable_id"
    t.string "action", null: false
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_notifications_on_actor_id"
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable"
    t.index ["user_id", "created_at"], name: "index_notifications_on_user_id_and_created_at"
    t.index ["user_id", "read_at"], name: "index_notifications_on_user_id_and_read_at"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "presentation_bottles", force: :cascade do |t|
    t.bigint "presentation_id", null: false
    t.bigint "bottle_id"
    t.integer "position", default: 0, null: false
    t.string "label"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.string "price"
    t.text "origin"
    t.text "style"
    t.text "notes"
    t.index ["bottle_id"], name: "index_presentation_bottles_on_bottle_id"
    t.index ["presentation_id", "bottle_id"], name: "index_presentation_bottles_on_presentation_id_and_bottle_id", unique: true
    t.index ["presentation_id"], name: "index_presentation_bottles_on_presentation_id"
  end

  create_table "presentation_reviews", force: :cascade do |t|
    t.bigint "presentation_id", null: false
    t.bigint "user_id", null: false
    t.decimal "rating", precision: 2, scale: 1, null: false
    t.text "body"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["presentation_id", "user_id"], name: "index_presentation_reviews_on_presentation_id_and_user_id", unique: true
    t.index ["presentation_id"], name: "index_presentation_reviews_on_presentation_id"
    t.index ["user_id"], name: "index_presentation_reviews_on_user_id"
  end

  create_table "presentation_tags", force: :cascade do |t|
    t.bigint "presentation_id", null: false
    t.bigint "tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["presentation_id", "tag_id"], name: "index_presentation_tags_on_presentation_id_and_tag_id", unique: true
    t.index ["presentation_id"], name: "index_presentation_tags_on_presentation_id"
    t.index ["tag_id"], name: "index_presentation_tags_on_tag_id"
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
    t.text "whiskey_recommendations"
    t.text "tasting_notes"
    t.text "nose_notes"
    t.text "palate_notes"
    t.text "finish_notes"
    t.text "body_notes"
    t.jsonb "whiskey_recommendations_json", default: []
    t.text "what_youll_learn"
    t.text "slides_preview"
    t.jsonb "file_access_settings", default: {}
    t.integer "download_count", default: 0
    t.integer "preview_pages", default: 3
    t.integer "preview_slide_count", default: 3, null: false
    t.boolean "featured", default: false, null: false
    t.integer "reviews_count", default: 0, null: false
    t.decimal "reviews_average", precision: 3, scale: 2
    t.index ["author_id"], name: "index_presentations_on_author_id"
    t.index ["category"], name: "index_presentations_on_category"
    t.index ["download_count"], name: "index_presentations_on_download_count"
    t.index ["featured"], name: "index_presentations_on_featured"
    t.index ["price"], name: "index_presentations_on_price"
    t.index ["title"], name: "index_presentations_on_title"
    t.index ["whiskey_recommendations_json"], name: "index_presentations_on_whiskey_recommendations_json", using: :gin
  end

  create_table "review_reports", force: :cascade do |t|
    t.bigint "review_id", null: false
    t.bigint "user_id", null: false
    t.string "status", default: "open", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["review_id"], name: "index_review_reports_on_review_id"
    t.index ["status"], name: "index_review_reports_on_status"
    t.index ["user_id", "review_id"], name: "index_review_reports_on_user_id_and_review_id", unique: true
    t.index ["user_id"], name: "index_review_reports_on_user_id"
  end

  create_table "review_votes", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "review_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["review_id"], name: "index_review_votes_on_review_id"
    t.index ["user_id", "review_id"], name: "index_review_votes_on_user_id_and_review_id", unique: true
    t.index ["user_id"], name: "index_review_votes_on_user_id"
  end

  create_table "reviews", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "bottle_id", null: false
    t.bigint "event_id"
    t.decimal "rating", precision: 2, scale: 1, null: false
    t.text "notes"
    t.string "nose"
    t.string "palate"
    t.string "finish"
    t.string "body_notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "price_paid", precision: 8, scale: 2
    t.jsonb "flavor_wheel", default: {}, null: false
    t.integer "votes_count", default: 0, null: false
    t.index ["bottle_id"], name: "index_reviews_on_bottle_id"
    t.index ["event_id"], name: "index_reviews_on_event_id"
    t.index ["user_id", "bottle_id", "event_id"], name: "index_reviews_on_user_id_and_bottle_id_and_event_id", unique: true
    t.index ["user_id", "bottle_id"], name: "index_reviews_solo_uniqueness", unique: true, where: "(event_id IS NULL)"
    t.index ["user_id"], name: "index_reviews_on_user_id"
  end

  create_table "shelf_items", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "bottle_id"
    t.string "custom_name"
    t.integer "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "user_id, lower((custom_name)::text)", name: "index_shelf_items_on_user_and_lower_custom_name", unique: true, where: "(custom_name IS NOT NULL)"
    t.index ["bottle_id"], name: "index_shelf_items_on_bottle_id"
    t.index ["user_id", "bottle_id"], name: "index_shelf_items_on_user_id_and_bottle_id", unique: true, where: "(bottle_id IS NOT NULL)"
    t.index ["user_id"], name: "index_shelf_items_on_user_id"
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
    t.string "invite_token"
    t.integer "favorites_count", default: 0, null: false
    t.text "about"
    t.index ["creator_id"], name: "index_societies_on_creator_id"
    t.index ["invite_token"], name: "index_societies_on_invite_token", unique: true
    t.index ["location"], name: "index_societies_on_location"
    t.index ["name"], name: "index_societies_on_name"
  end

  create_table "society_activities", force: :cascade do |t|
    t.bigint "society_id", null: false
    t.bigint "user_id", null: false
    t.bigint "actor_id"
    t.string "action", null: false
    t.string "detail"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_society_activities_on_actor_id"
    t.index ["society_id", "created_at"], name: "index_society_activities_on_society_id_and_created_at"
    t.index ["society_id"], name: "index_society_activities_on_society_id"
    t.index ["user_id"], name: "index_society_activities_on_user_id"
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

  create_table "society_invitations", force: :cascade do |t|
    t.bigint "society_id", null: false
    t.bigint "user_id", null: false
    t.bigint "invited_by_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "responded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["invited_by_id"], name: "index_society_invitations_on_invited_by_id"
    t.index ["society_id", "user_id"], name: "index_society_invitations_on_pending_pair", unique: true, where: "((status)::text = 'pending'::text)"
    t.index ["society_id"], name: "index_society_invitations_on_society_id"
    t.index ["user_id"], name: "index_society_invitations_on_user_id"
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
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
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

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
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

  create_table "stripe_events", force: :cascade do |t|
    t.string "stripe_event_id", null: false
    t.string "event_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["stripe_event_id"], name: "index_stripe_events_on_stripe_event_id", unique: true
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
    t.integer "credits", default: 0, null: false
    t.boolean "cancel_at_period_end", default: false
    t.boolean "is_admin", default: false, null: false
    t.datetime "subscription_paused_at"
    t.string "magic_link_token"
    t.datetime "magic_link_sent_at"
    t.integer "favorites_count", default: 0, null: false
    t.string "admin_role", default: "none", null: false
    t.boolean "founding_member", default: false, null: false
    t.datetime "founding_revoked_at"
    t.boolean "event_emails", default: true, null: false
    t.string "invitation_token_digest"
    t.datetime "invitation_sent_at"
    t.datetime "invitation_accepted_at"
    t.bigint "invited_by_id"
    t.index ["admin_role"], name: "index_users_on_admin_role"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["founding_member"], name: "index_users_on_founding_member"
    t.index ["invitation_token_digest"], name: "index_users_on_invitation_token_digest"
    t.index ["invited_by_id"], name: "index_users_on_invited_by_id"
    t.index ["is_admin"], name: "index_users_on_is_admin"
    t.index ["magic_link_token"], name: "index_users_on_magic_link_token", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "activity_logs", "users"
  add_foreign_key "bottle_edits", "bottles"
  add_foreign_key "bottle_edits", "users"
  add_foreign_key "bottle_edits", "users", column: "applied_by_id"
  add_foreign_key "bottles", "users", column: "created_by_id"
  add_foreign_key "credit_transactions", "presentations"
  add_foreign_key "credit_transactions", "users"
  add_foreign_key "download_logs", "presentations"
  add_foreign_key "download_logs", "users"
  add_foreign_key "event_bottles", "bottles"
  add_foreign_key "event_bottles", "events"
  add_foreign_key "event_comments", "events"
  add_foreign_key "event_comments", "users"
  add_foreign_key "event_rsvps", "events"
  add_foreign_key "event_rsvps", "users"
  add_foreign_key "events", "presentations"
  add_foreign_key "events", "societies"
  add_foreign_key "events", "users", column: "host_id"
  add_foreign_key "events", "users", column: "organizer_id"
  add_foreign_key "favorites", "users"
  add_foreign_key "notifications", "users"
  add_foreign_key "notifications", "users", column: "actor_id"
  add_foreign_key "presentation_bottles", "bottles"
  add_foreign_key "presentation_bottles", "presentations"
  add_foreign_key "presentation_reviews", "presentations"
  add_foreign_key "presentation_reviews", "users"
  add_foreign_key "presentation_tags", "presentations"
  add_foreign_key "presentation_tags", "tags"
  add_foreign_key "presentations", "users", column: "author_id"
  add_foreign_key "review_reports", "reviews"
  add_foreign_key "review_reports", "users"
  add_foreign_key "review_votes", "reviews"
  add_foreign_key "review_votes", "users"
  add_foreign_key "reviews", "bottles"
  add_foreign_key "reviews", "events"
  add_foreign_key "reviews", "users"
  add_foreign_key "shelf_items", "bottles"
  add_foreign_key "shelf_items", "users"
  add_foreign_key "societies", "users", column: "creator_id"
  add_foreign_key "society_activities", "societies"
  add_foreign_key "society_activities", "users"
  add_foreign_key "society_activities", "users", column: "actor_id"
  add_foreign_key "society_applications", "societies"
  add_foreign_key "society_applications", "users"
  add_foreign_key "society_invitations", "societies"
  add_foreign_key "society_invitations", "users"
  add_foreign_key "society_invitations", "users", column: "invited_by_id"
  add_foreign_key "society_memberships", "societies"
  add_foreign_key "society_memberships", "users"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "user_presentations", "presentations"
  add_foreign_key "user_presentations", "users"
  add_foreign_key "user_tags", "tags"
  add_foreign_key "user_tags", "users"
  add_foreign_key "users", "users", column: "invited_by_id"
end
