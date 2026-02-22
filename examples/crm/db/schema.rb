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

ActiveRecord::Schema[7.2].define(version: 2026_02_19_104942) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index [ "blob_id" ], name: "index_active_storage_attachments_on_blob_id"
    t.index [ "record_type", "record_id", "name", "blob_id" ], name: "index_active_storage_attachments_uniqueness", unique: true
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
    t.index [ "key" ], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index [ "blob_id", "variation_digest" ], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "cities", force: :cascade do |t|
    t.string "name", limit: 255, null: false
    t.integer "population"
    t.bigint "region_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "region_id" ], name: "index_cities_on_region_id"
  end

  create_table "companies", force: :cascade do |t|
    t.string "name", limit: 255, null: false
    t.string "industry"
    t.string "website", limit: 2048
    t.string "phone", limit: 50
    t.string "address_type", default: "unknown"
    t.string "street"
    t.bigint "country_id"
    t.bigint "region_id"
    t.bigint "city_id"
    t.json "custom_data", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "city_id" ], name: "index_companies_on_city_id"
    t.index [ "country_id" ], name: "index_companies_on_country_id"
    t.index [ "region_id" ], name: "index_companies_on_region_id"
  end

  create_table "contacts", force: :cascade do |t|
    t.string "first_name", limit: 100, null: false
    t.string "last_name", limit: 100, null: false
    t.string "full_name"
    t.string "email", limit: 255
    t.string "phone", limit: 50
    t.string "position"
    t.boolean "active", default: true
    t.bigint "company_id", null: false
    t.json "custom_data", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "company_id" ], name: "index_contacts_on_company_id"
  end

  create_table "countries", force: :cascade do |t|
    t.string "name", limit: 255, null: false
    t.string "code", limit: 3
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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

  create_table "deal_categories", force: :cascade do |t|
    t.string "name", limit: 255, null: false
    t.bigint "parent_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "parent_id" ], name: "index_deal_categories_on_parent_id"
  end

  create_table "deals", force: :cascade do |t|
    t.string "title", limit: 255, null: false
    t.string "stage", default: "lead"
    t.decimal "value", precision: 12, scale: 2
    t.integer "priority", default: 50
    t.integer "progress", default: 0
    t.decimal "weighted_value", precision: 12, scale: 2
    t.date "expected_close_date"
    t.bigint "company_id", null: false
    t.bigint "contact_id"
    t.bigint "deal_category_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "company_id" ], name: "index_deals_on_company_id"
    t.index [ "contact_id" ], name: "index_deals_on_contact_id"
    t.index [ "deal_category_id" ], name: "index_deals_on_deal_category_id"
  end

  create_table "regions", force: :cascade do |t|
    t.string "name", limit: 255, null: false
    t.bigint "country_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "country_id" ], name: "index_regions_on_country_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
end
