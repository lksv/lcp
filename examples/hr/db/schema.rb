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

ActiveRecord::Schema[7.2].define(version: 2026_03_03_202825) do
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

  create_table "announcements", force: :cascade do |t|
    t.string "title", null: false
    t.text "body"
    t.string "priority", default: "normal"
    t.boolean "published"
    t.datetime "published_at"
    t.date "expires_at"
    t.boolean "pinned"
    t.bigint "organization_unit_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "created_by_id"
    t.bigint "updated_by_id"
    t.string "created_by_name"
    t.string "updated_by_name"
    t.datetime "discarded_at"
    t.string "discarded_by_type"
    t.bigint "discarded_by_id"
    t.index ["created_by_id"], name: "index_announcements_on_created_by_id"
    t.index ["discarded_at"], name: "index_announcements_on_discarded_at"
    t.index ["discarded_by_type", "discarded_by_id"], name: "index_announcements_on_discarded_by_type_and_discarded_by_id"
    t.index ["organization_unit_id"], name: "index_announcements_on_organization_unit_id"
    t.index ["updated_by_id"], name: "index_announcements_on_updated_by_id"
  end

  create_table "asset_assignments", force: :cascade do |t|
    t.date "assigned_at", null: false
    t.date "returned_at"
    t.string "condition_on_assign"
    t.string "condition_on_return"
    t.text "notes"
    t.bigint "asset_id", null: false
    t.bigint "employee_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "created_by_id"
    t.bigint "updated_by_id"
    t.string "created_by_name"
    t.string "updated_by_name"
    t.index ["asset_id"], name: "index_asset_assignments_on_asset_id"
    t.index ["created_by_id"], name: "index_asset_assignments_on_created_by_id"
    t.index ["employee_id"], name: "index_asset_assignments_on_employee_id"
    t.index ["updated_by_id"], name: "index_asset_assignments_on_updated_by_id"
  end

  create_table "assets", force: :cascade do |t|
    t.string "name", limit: 255, null: false
    t.string "asset_tag", limit: 50, null: false
    t.string "asset_uuid"
    t.string "category"
    t.string "brand", limit: 100
    t.string "product_model", limit: 100
    t.string "serial_number", limit: 100
    t.date "purchase_date"
    t.decimal "purchase_price", precision: 10, scale: 2
    t.date "warranty_until"
    t.string "status", default: "available"
    t.text "notes"
    t.json "custom_data", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "created_by_id"
    t.bigint "updated_by_id"
    t.string "created_by_name"
    t.string "updated_by_name"
    t.datetime "discarded_at"
    t.string "discarded_by_type"
    t.bigint "discarded_by_id"
    t.index ["created_by_id"], name: "index_assets_on_created_by_id"
    t.index ["discarded_at"], name: "index_assets_on_discarded_at"
    t.index ["discarded_by_type", "discarded_by_id"], name: "index_assets_on_discarded_by_type_and_discarded_by_id"
    t.index ["updated_by_id"], name: "index_assets_on_updated_by_id"
  end

  create_table "audit_logs", force: :cascade do |t|
    t.string "auditable_type"
    t.integer "auditable_id"
    t.string "action"
    t.json "changes_data"
    t.integer "user_id"
    t.json "user_snapshot"
    t.json "metadata"
    t.datetime "created_at"
  end

  create_table "candidates", force: :cascade do |t|
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "full_name"
    t.string "email", limit: 255, null: false
    t.string "phone", limit: 50
    t.string "status", default: "applied"
    t.string "source"
    t.text "cover_letter"
    t.integer "rating"
    t.text "notes"
    t.text "rejection_reason"
    t.bigint "job_posting_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "created_by_id"
    t.bigint "updated_by_id"
    t.string "created_by_name"
    t.string "updated_by_name"
    t.index ["created_by_id"], name: "index_candidates_on_created_by_id"
    t.index ["job_posting_id"], name: "index_candidates_on_job_posting_id"
    t.index ["updated_by_id"], name: "index_candidates_on_updated_by_id"
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
    t.string "hint"
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
    t.boolean "filterable"
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

  create_table "documents", force: :cascade do |t|
    t.string "title", null: false
    t.string "category"
    t.text "description"
    t.boolean "confidential"
    t.date "valid_from"
    t.date "valid_until"
    t.bigint "employee_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "created_by_id"
    t.bigint "updated_by_id"
    t.string "created_by_name"
    t.string "updated_by_name"
    t.index ["created_by_id"], name: "index_documents_on_created_by_id"
    t.index ["employee_id"], name: "index_documents_on_employee_id"
    t.index ["updated_by_id"], name: "index_documents_on_updated_by_id"
  end

  create_table "employee_skills", force: :cascade do |t|
    t.string "proficiency"
    t.boolean "certified"
    t.date "certified_at"
    t.date "expires_at"
    t.bigint "employee_id", null: false
    t.bigint "skill_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id"], name: "index_employee_skills_on_employee_id"
    t.index ["skill_id"], name: "index_employee_skills_on_skill_id"
  end

  create_table "employees", force: :cascade do |t|
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "full_name"
    t.string "personal_email", limit: 255
    t.string "work_email", limit: 255, null: false
    t.string "phone", limit: 50
    t.date "date_of_birth"
    t.date "hire_date", null: false
    t.date "termination_date"
    t.string "status", default: "active"
    t.string "employment_type"
    t.string "gender"
    t.decimal "salary", precision: 10, scale: 2
    t.string "currency", default: "CZK"
    t.json "address"
    t.json "emergency_contact"
    t.text "notes"
    t.bigint "organization_unit_id", null: false
    t.bigint "position_id", null: false
    t.bigint "manager_id"
    t.json "custom_data", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "created_by_id"
    t.bigint "updated_by_id"
    t.string "created_by_name"
    t.string "updated_by_name"
    t.datetime "discarded_at"
    t.string "discarded_by_type"
    t.bigint "discarded_by_id"
    t.index ["created_by_id"], name: "index_employees_on_created_by_id"
    t.index ["discarded_at"], name: "index_employees_on_discarded_at"
    t.index ["discarded_by_type", "discarded_by_id"], name: "index_employees_on_discarded_by_type_and_discarded_by_id"
    t.index ["manager_id"], name: "index_employees_on_manager_id"
    t.index ["organization_unit_id"], name: "index_employees_on_organization_unit_id"
    t.index ["position_id"], name: "index_employees_on_position_id"
    t.index ["updated_by_id"], name: "index_employees_on_updated_by_id"
  end

  create_table "expense_claims", force: :cascade do |t|
    t.string "title", null: false
    t.text "description"
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.string "currency", default: "CZK"
    t.string "category"
    t.string "status", default: "draft"
    t.date "expense_date", null: false
    t.integer "approved_by_id"
    t.datetime "approved_at"
    t.text "rejection_note"
    t.json "items"
    t.bigint "employee_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "created_by_id"
    t.bigint "updated_by_id"
    t.string "created_by_name"
    t.string "updated_by_name"
    t.index ["created_by_id"], name: "index_expense_claims_on_created_by_id"
    t.index ["employee_id"], name: "index_expense_claims_on_employee_id"
    t.index ["updated_by_id"], name: "index_expense_claims_on_updated_by_id"
  end

  create_table "goals", force: :cascade do |t|
    t.string "title", null: false
    t.text "description"
    t.string "status", default: "not_started"
    t.string "priority", default: "medium"
    t.date "due_date"
    t.integer "progress", default: 0
    t.integer "weight", default: 1
    t.integer "position", null: false
    t.bigint "employee_id", null: false
    t.bigint "performance_review_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "created_by_id"
    t.bigint "updated_by_id"
    t.string "created_by_name"
    t.string "updated_by_name"
    t.index ["created_by_id"], name: "index_goals_on_created_by_id"
    t.index ["employee_id"], name: "index_goals_on_employee_id"
    t.index ["performance_review_id"], name: "index_goals_on_performance_review_id"
    t.index ["updated_by_id"], name: "index_goals_on_updated_by_id"
  end

  create_table "group_memberships", force: :cascade do |t|
    t.string "role_in_group", default: "member"
    t.date "joined_at", null: false
    t.date "left_at"
    t.boolean "active", default: true
    t.bigint "group_id", null: false
    t.bigint "employee_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "created_by_id"
    t.bigint "updated_by_id"
    t.string "created_by_name"
    t.string "updated_by_name"
    t.index ["created_by_id"], name: "index_group_memberships_on_created_by_id"
    t.index ["employee_id"], name: "index_group_memberships_on_employee_id"
    t.index ["group_id"], name: "index_group_memberships_on_group_id"
    t.index ["updated_by_id"], name: "index_group_memberships_on_updated_by_id"
  end

  create_table "groups", force: :cascade do |t|
    t.string "name", null: false
    t.string "code", null: false
    t.text "description"
    t.string "group_type"
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "created_by_id"
    t.bigint "updated_by_id"
    t.string "created_by_name"
    t.string "updated_by_name"
    t.index ["created_by_id"], name: "index_groups_on_created_by_id"
    t.index ["updated_by_id"], name: "index_groups_on_updated_by_id"
  end

  create_table "interviews", force: :cascade do |t|
    t.string "interview_type"
    t.datetime "scheduled_at", null: false
    t.integer "duration_minutes", default: 60
    t.string "location"
    t.string "meeting_url", limit: 2048
    t.string "status", default: "scheduled"
    t.integer "rating"
    t.text "feedback"
    t.string "recommendation"
    t.json "notes"
    t.bigint "candidate_id", null: false
    t.bigint "interviewer_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "created_by_id"
    t.bigint "updated_by_id"
    t.string "created_by_name"
    t.string "updated_by_name"
    t.index ["candidate_id"], name: "index_interviews_on_candidate_id"
    t.index ["created_by_id"], name: "index_interviews_on_created_by_id"
    t.index ["interviewer_id"], name: "index_interviews_on_interviewer_id"
    t.index ["updated_by_id"], name: "index_interviews_on_updated_by_id"
  end

  create_table "job_postings", force: :cascade do |t|
    t.string "title", null: false
    t.text "description"
    t.string "status", default: "draft"
    t.string "employment_type"
    t.string "location"
    t.string "remote_option"
    t.decimal "salary_min", precision: 10, scale: 2
    t.decimal "salary_max", precision: 10, scale: 2
    t.string "currency", default: "CZK"
    t.integer "headcount", default: 1
    t.datetime "published_at"
    t.date "closes_at"
    t.bigint "organization_unit_id", null: false
    t.bigint "position_id", null: false
    t.bigint "hiring_manager_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "created_by_id"
    t.bigint "updated_by_id"
    t.string "created_by_name"
    t.string "updated_by_name"
    t.datetime "discarded_at"
    t.string "discarded_by_type"
    t.bigint "discarded_by_id"
    t.index ["created_by_id"], name: "index_job_postings_on_created_by_id"
    t.index ["discarded_at"], name: "index_job_postings_on_discarded_at"
    t.index ["discarded_by_type", "discarded_by_id"], name: "index_job_postings_on_discarded_by_type_and_discarded_by_id"
    t.index ["hiring_manager_id"], name: "index_job_postings_on_hiring_manager_id"
    t.index ["organization_unit_id"], name: "index_job_postings_on_organization_unit_id"
    t.index ["position_id"], name: "index_job_postings_on_position_id"
    t.index ["updated_by_id"], name: "index_job_postings_on_updated_by_id"
  end

  create_table "leave_balances", force: :cascade do |t|
    t.integer "year", null: false
    t.decimal "total_days", precision: 4, scale: 1, null: false
    t.decimal "used_days", precision: 4, scale: 1, default: "0.0"
    t.decimal "remaining", precision: 4, scale: 1
    t.bigint "employee_id", null: false
    t.bigint "leave_type_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "created_by_id"
    t.bigint "updated_by_id"
    t.string "created_by_name"
    t.string "updated_by_name"
    t.index ["created_by_id"], name: "index_leave_balances_on_created_by_id"
    t.index ["employee_id"], name: "index_leave_balances_on_employee_id"
    t.index ["leave_type_id"], name: "index_leave_balances_on_leave_type_id"
    t.index ["updated_by_id"], name: "index_leave_balances_on_updated_by_id"
  end

  create_table "leave_requests", force: :cascade do |t|
    t.date "start_date", null: false
    t.date "end_date", null: false
    t.decimal "days_count", precision: 4, scale: 1
    t.string "status", default: "draft"
    t.text "reason"
    t.text "rejection_note"
    t.integer "approved_by_id"
    t.datetime "approved_at"
    t.bigint "employee_id", null: false
    t.bigint "leave_type_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "created_by_id"
    t.bigint "updated_by_id"
    t.string "created_by_name"
    t.string "updated_by_name"
    t.index ["created_by_id"], name: "index_leave_requests_on_created_by_id"
    t.index ["employee_id"], name: "index_leave_requests_on_employee_id"
    t.index ["leave_type_id"], name: "index_leave_requests_on_leave_type_id"
    t.index ["updated_by_id"], name: "index_leave_requests_on_updated_by_id"
  end

  create_table "leave_types", force: :cascade do |t|
    t.string "name", limit: 255, null: false
    t.string "code", limit: 50, null: false
    t.string "color", limit: 7
    t.integer "default_days", default: 0
    t.boolean "requires_approval", default: true
    t.boolean "requires_document"
    t.boolean "active", default: true
    t.integer "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "organization_units", force: :cascade do |t|
    t.string "name", limit: 255, null: false
    t.string "code", limit: 50, null: false
    t.text "description"
    t.decimal "budget", precision: 12, scale: 2
    t.boolean "active", default: true
    t.integer "parent_id"
    t.integer "head_id"
    t.json "custom_data", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "created_by_id"
    t.bigint "updated_by_id"
    t.string "created_by_name"
    t.string "updated_by_name"
    t.datetime "discarded_at"
    t.string "discarded_by_type"
    t.bigint "discarded_by_id"
    t.index ["created_by_id"], name: "index_organization_units_on_created_by_id"
    t.index ["discarded_at"], name: "index_organization_units_on_discarded_at"
    t.index ["discarded_by_type", "discarded_by_id"], name: "idx_on_discarded_by_type_discarded_by_id_2380496adc"
    t.index ["parent_id"], name: "index_organization_units_on_parent_id"
    t.index ["updated_by_id"], name: "index_organization_units_on_updated_by_id"
  end

  create_table "performance_reviews", force: :cascade do |t|
    t.string "review_period"
    t.integer "year", null: false
    t.string "status", default: "draft"
    t.integer "self_rating"
    t.integer "manager_rating"
    t.integer "overall_rating"
    t.text "self_comments"
    t.text "manager_comments"
    t.text "goals_summary"
    t.text "strengths"
    t.text "improvements"
    t.datetime "completed_at"
    t.bigint "employee_id", null: false
    t.bigint "reviewer_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "created_by_id"
    t.bigint "updated_by_id"
    t.string "created_by_name"
    t.string "updated_by_name"
    t.index ["created_by_id"], name: "index_performance_reviews_on_created_by_id"
    t.index ["employee_id"], name: "index_performance_reviews_on_employee_id"
    t.index ["reviewer_id"], name: "index_performance_reviews_on_reviewer_id"
    t.index ["updated_by_id"], name: "index_performance_reviews_on_updated_by_id"
  end

  create_table "positions", force: :cascade do |t|
    t.string "title", limit: 255, null: false
    t.string "code", limit: 50, null: false
    t.integer "level"
    t.decimal "min_salary", precision: 10, scale: 2
    t.decimal "max_salary", precision: 10, scale: 2
    t.boolean "active", default: true
    t.integer "parent_id"
    t.integer "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "discarded_at"
    t.string "discarded_by_type"
    t.bigint "discarded_by_id"
    t.index ["discarded_at"], name: "index_positions_on_discarded_at"
    t.index ["discarded_by_type", "discarded_by_id"], name: "index_positions_on_discarded_by_type_and_discarded_by_id"
    t.index ["parent_id"], name: "index_positions_on_parent_id"
  end

  create_table "skills", force: :cascade do |t|
    t.string "name", limit: 255, null: false
    t.text "description"
    t.string "category"
    t.integer "parent_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_skills_on_parent_id"
  end

  create_table "training_courses", force: :cascade do |t|
    t.string "title", limit: 255, null: false
    t.text "description"
    t.string "category"
    t.string "format"
    t.decimal "duration_hours", precision: 5, scale: 1
    t.integer "max_participants"
    t.string "instructor", limit: 255
    t.string "location", limit: 255
    t.string "url", limit: 2048
    t.datetime "starts_at"
    t.datetime "ends_at"
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "created_by_id"
    t.bigint "updated_by_id"
    t.string "created_by_name"
    t.string "updated_by_name"
    t.datetime "discarded_at"
    t.string "discarded_by_type"
    t.bigint "discarded_by_id"
    t.index ["created_by_id"], name: "index_training_courses_on_created_by_id"
    t.index ["discarded_at"], name: "index_training_courses_on_discarded_at"
    t.index ["discarded_by_type", "discarded_by_id"], name: "idx_on_discarded_by_type_discarded_by_id_204bf8a07f"
    t.index ["updated_by_id"], name: "index_training_courses_on_updated_by_id"
  end

  create_table "training_enrollments", force: :cascade do |t|
    t.string "status", default: "enrolled"
    t.datetime "completed_at"
    t.integer "score"
    t.text "feedback"
    t.bigint "employee_id", null: false
    t.bigint "training_course_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "created_by_id"
    t.bigint "updated_by_id"
    t.string "created_by_name"
    t.string "updated_by_name"
    t.index ["created_by_id"], name: "index_training_enrollments_on_created_by_id"
    t.index ["employee_id"], name: "index_training_enrollments_on_employee_id"
    t.index ["training_course_id"], name: "index_training_enrollments_on_training_course_id"
    t.index ["updated_by_id"], name: "index_training_enrollments_on_updated_by_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
end
