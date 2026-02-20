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

ActiveRecord::Schema[7.2].define(version: 2026_02_20_072723) do
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

  create_table "article_tags", force: :cascade do |t|
    t.bigint "article_id", null: false
    t.bigint "tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["article_id"], name: "index_article_tags_on_article_id"
    t.index ["tag_id"], name: "index_article_tags_on_tag_id"
  end

  create_table "articles", force: :cascade do |t|
    t.string "title", limit: 255, null: false
    t.text "body"
    t.string "status", default: "draft"
    t.integer "word_count", default: 0
    t.bigint "category_id", null: false
    t.bigint "author_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_articles_on_author_id"
    t.index ["category_id"], name: "index_articles_on_category_id"
  end

  create_table "authors", force: :cascade do |t|
    t.string "name", limit: 100, null: false
    t.string "email", limit: 255
    t.text "bio"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "categories", force: :cascade do |t|
    t.string "name", limit: 100, null: false
    t.text "description"
    t.bigint "parent_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_categories_on_parent_id"
  end

  create_table "comments", force: :cascade do |t|
    t.text "body", null: false
    t.string "author_name", limit: 100, null: false
    t.integer "position", default: 0
    t.bigint "article_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["article_id"], name: "index_comments_on_article_id"
  end

  create_table "custom_field_definitions", force: :cascade do |t|
    t.string "target_model"
    t.string "field_name"
    t.string "custom_type", default: "string"
    t.string "label"
    t.text "description"
    t.string "section", default: "Custom Fields"
    t.integer "position", default: 0
    t.boolean "active", default: true
    t.boolean "required"
    t.string "default_value"
    t.string "placeholder"
    t.integer "min_length"
    t.integer "max_length"
    t.decimal "min_value", precision: 15, scale: 4
    t.decimal "max_value", precision: 15, scale: 4
    t.integer "precision"
    t.json "enum_values"
    t.boolean "show_in_table"
    t.boolean "show_in_form", default: true
    t.boolean "show_in_show", default: true
    t.boolean "sortable"
    t.boolean "searchable"
    t.string "input_type"
    t.string "renderer"
    t.json "renderer_options"
    t.string "column_width"
    t.json "extra_validations"
    t.json "readable_by_roles"
    t.json "writable_by_roles"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "departments", force: :cascade do |t|
    t.string "name", limit: 100, null: false
    t.string "code", limit: 20
    t.bigint "parent_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_departments_on_parent_id"
  end

  create_table "employee_skills", force: :cascade do |t|
    t.bigint "employee_id", null: false
    t.bigint "skill_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id"], name: "index_employee_skills_on_employee_id"
    t.index ["skill_id"], name: "index_employee_skills_on_skill_id"
  end

  create_table "employees", force: :cascade do |t|
    t.string "name", limit: 100, null: false
    t.string "email", limit: 255
    t.string "role", default: "developer"
    t.string "status", default: "active"
    t.bigint "department_id", null: false
    t.bigint "mentor_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["department_id"], name: "index_employees_on_department_id"
    t.index ["mentor_id"], name: "index_employees_on_mentor_id"
  end

  create_table "features", force: :cascade do |t|
    t.string "name", limit: 100, null: false
    t.string "category", null: false
    t.text "description"
    t.text "config_example"
    t.string "demo_path", limit: 255
    t.text "demo_hint"
    t.string "status", default: "stable"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "lcp_ruby_users", force: :cascade do |t|
    t.string "name", null: false
    t.json "lcp_role", default: ["viewer"]
    t.boolean "active", default: true, null: false
    t.json "profile_data", default: {}
    t.string "email", default: "", null: false
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
    t.index ["email"], name: "index_lcp_ruby_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_lcp_ruby_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_lcp_ruby_users_on_unlock_token", unique: true
  end

  create_table "projects", force: :cascade do |t|
    t.string "name", limit: 200, null: false
    t.string "status", default: "active"
    t.bigint "department_id", null: false
    t.bigint "lead_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["department_id"], name: "index_projects_on_department_id"
    t.index ["lead_id"], name: "index_projects_on_lead_id"
  end

  create_table "roles", force: :cascade do |t|
    t.string "name", limit: 50, null: false
    t.string "label", limit: 100
    t.text "description"
    t.boolean "active", default: true
    t.integer "position", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "showcase_attachments", force: :cascade do |t|
    t.string "title", limit: 255, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "showcase_extensibilities", force: :cascade do |t|
    t.string "name", limit: 100, null: false
    t.string "currency", limit: 3
    t.decimal "amount", precision: 12, scale: 2
    t.integer "score"
    t.string "normalized_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "showcase_fields", force: :cascade do |t|
    t.string "title", limit: 255, null: false
    t.text "description"
    t.text "notes"
    t.integer "count", default: 0
    t.float "rating_value"
    t.decimal "price", precision: 10, scale: 2
    t.boolean "is_active", default: true
    t.date "start_date"
    t.datetime "event_time"
    t.string "status", default: "draft"
    t.string "priority", default: "medium"
    t.json "metadata"
    t.string "external_id"
    t.string "email", limit: 255
    t.string "phone", limit: 50
    t.string "website", limit: 2048
    t.string "brand_color", limit: 7
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "showcase_forms", force: :cascade do |t|
    t.string "name", limit: 100, null: false
    t.string "form_type", default: "simple"
    t.integer "priority", default: 50
    t.integer "satisfaction", default: 3
    t.boolean "is_premium"
    t.text "detailed_notes"
    t.json "config_data"
    t.string "reason", limit: 255
    t.text "rejection_reason"
    t.string "advanced_field_1", limit: 255
    t.string "advanced_field_2", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "showcase_models", force: :cascade do |t|
    t.string "name", limit: 100, null: false
    t.string "code", limit: 50
    t.string "status", default: "draft"
    t.decimal "amount", precision: 10, scale: 2
    t.date "due_date"
    t.date "auto_date"
    t.string "computed_label"
    t.decimal "computed_score", precision: 10, scale: 2
    t.string "email", limit: 255
    t.string "phone", limit: 50
    t.string "website", limit: 2048
    t.integer "max_value", default: 100
    t.integer "min_value"
    t.json "tags_json"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "showcase_permissions", force: :cascade do |t|
    t.string "title", limit: 255, null: false
    t.string "status", default: "open"
    t.integer "owner_id", default: 1
    t.integer "assignee_id"
    t.string "priority", default: "medium"
    t.boolean "confidential"
    t.text "internal_notes"
    t.text "public_notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "skills", force: :cascade do |t|
    t.string "name", limit: 100, null: false
    t.string "category"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "tags", force: :cascade do |t|
    t.string "name", limit: 50, null: false
    t.string "color", limit: 7
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
end
