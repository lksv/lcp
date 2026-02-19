ENV["RAILS_ENV"] = "test"

require_relative "dummy/config/environment"

require "rspec/rails"

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.before(:suite) do
    # Ensure Active Storage tables exist for attachment tests
    ActiveRecord::Schema.define do
      unless ActiveRecord::Base.connection.table_exists?(:active_storage_blobs)
        create_table :active_storage_blobs do |t|
          t.string   :key,          null: false
          t.string   :filename,     null: false
          t.string   :content_type
          t.text     :metadata
          t.string   :service_name, null: false
          t.bigint   :byte_size,    null: false
          t.string   :checksum

          t.datetime :created_at,   null: false

          t.index [ :key ], unique: true
        end
      end

      unless ActiveRecord::Base.connection.table_exists?(:active_storage_attachments)
        create_table :active_storage_attachments do |t|
          t.string     :name,     null: false
          t.references :record,   null: false, polymorphic: true, index: false
          t.references :blob,     null: false, index: false

          t.datetime :created_at, null: false

          t.index [ :record_type, :record_id, :name, :blob_id ], name: :index_active_storage_attachments_uniqueness, unique: true
          t.index [ :blob_id ], name: :index_active_storage_attachments_on_blob_id
        end
      end

      unless ActiveRecord::Base.connection.table_exists?(:active_storage_variant_records)
        create_table :active_storage_variant_records do |t|
          t.belongs_to :blob, null: false, index: false
          t.string :variation_digest, null: false

          t.index [ :blob_id, :variation_digest ], name: :index_active_storage_variant_records_uniqueness, unique: true
        end
      end
    end
  end

  config.before(:each) do
    LcpRuby.reset!
  end
end
