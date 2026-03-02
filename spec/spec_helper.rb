ENV["RAILS_ENV"] = "test"

if ENV.fetch("COVERAGE", nil)
  require "simplecov"
  SimpleCov.start do
    root File.expand_path("..", __dir__)
    coverage_dir "tmp/coverage"

    track_files "{lib,app}/**/*.rb"

    add_filter "/spec/"
    add_filter "/examples/"

    add_group "Metadata",     "lib/lcp_ruby/metadata"
    add_group "ModelFactory",  "lib/lcp_ruby/model_factory"
    add_group "Presenter",     "lib/lcp_ruby/presenter"
    add_group "Search",        "lib/lcp_ruby/search"
    add_group "Authorization", "lib/lcp_ruby/authorization"
    add_group "Display",       "lib/lcp_ruby/display"
    add_group "CustomFields",  "lib/lcp_ruby/custom_fields"
    add_group "Groups",        "lib/lcp_ruby/groups"
    add_group "Permissions",   "lib/lcp_ruby/permissions"
    add_group "Auditing",      "lib/lcp_ruby/auditing"
    add_group "Roles",         "lib/lcp_ruby/roles"
    add_group "Types",         "lib/lcp_ruby/types"
    add_group "Events",        "lib/lcp_ruby/events"
    add_group "Actions",       "lib/lcp_ruby/actions"
    add_group "Controllers",   "app/controllers"
    add_group "Helpers",       "app/helpers"
    add_group "Generators",    "lib/generators"
  end
end

require_relative "dummy/config/environment"

require "rspec/rails"

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.before(:suite) do
    # Force-load all engine files so SimpleCov tracks Zeitwerk-autoloaded code
    if ENV.fetch("COVERAGE", nil)
      Dir[File.expand_path("../lib/lcp_ruby/**/*.rb", __dir__)].sort.each do |f|
        load f
      rescue StandardError
        nil
      end
      Dir[File.expand_path("../app/**/*.rb", __dir__)].sort.each do |f|
        load f
      rescue StandardError
        nil
      end
    end
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
