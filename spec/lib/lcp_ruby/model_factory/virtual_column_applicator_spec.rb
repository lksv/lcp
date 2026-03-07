require "spec_helper"

RSpec.describe LcpRuby::ModelFactory::VirtualColumnApplicator do
  before do
    LcpRuby.reset!
    LcpRuby::Types::BuiltInTypes.register_all!
    LcpRuby::Services::BuiltInTransforms.register_all!
    LcpRuby::Services::BuiltInDefaults.register_all!
  end

  def build_model(name, hash)
    model_def = LcpRuby::Metadata::ModelDefinition.from_hash(hash)
    LcpRuby.loader.model_definitions[name] = model_def
    schema_manager = LcpRuby::ModelFactory::SchemaManager.new(model_def)
    schema_manager.ensure_table!
    builder = LcpRuby::ModelFactory::Builder.new(model_def)
    model_class = builder.build
    LcpRuby.registry.register(name, model_class)
    [ model_def, model_class ]
  end

  describe "attribute declarations" do
    let!(:setup) do
      build_model("vca_test", {
        "name" => "vca_test",
        "fields" => [
          { "name" => "title", "type" => "string" }
        ],
        "associations" => [
          { "type" => "has_many", "name" => "vca_items", "target_model" => "vca_item", "foreign_key" => "vca_test_id" }
        ],
        "virtual_columns" => {
          "items_count" => { "function" => "count", "association" => "vca_items" },
          "is_active" => { "expression" => "1", "type" => "boolean" },
          "score" => { "expression" => "42.5", "type" => "float" }
        }
      })
    end

    let!(:item_setup) do
      build_model("vca_item", {
        "name" => "vca_item",
        "fields" => [
          { "name" => "name", "type" => "string" },
          { "name" => "vca_test_id", "type" => "integer" }
        ]
      })
    end

    let(:model_class) { setup[1] }

    after(:all) do
      conn = ActiveRecord::Base.connection
      conn.drop_table("vca_tests", if_exists: true)
      conn.drop_table("vca_items", if_exists: true)
    end

    it "installs AR attributes for type coercion" do
      # The attribute declarations are installed by VirtualColumnApplicator during build
      attrs = model_class.attribute_types
      expect(attrs.key?("items_count")).to be true
      expect(attrs.key?("is_active")).to be true
      expect(attrs.key?("score")).to be true
    end

    it "coerces integer type" do
      record = model_class.new
      record.write_attribute("items_count", "5")
      expect(record.read_attribute("items_count")).to eq(5)
    end

    it "coerces boolean type" do
      record = model_class.new
      record.write_attribute("is_active", 1)
      expect(record.read_attribute("is_active")).to be true
    end

    it "maps json type to AR :json attribute" do
      json_model_def, json_model_class = build_model("vca_json", {
        "name" => "vca_json",
        "fields" => [ { "name" => "title", "type" => "string" } ],
        "virtual_columns" => {
          "meta" => { "expression" => "'[]'", "type" => "json" }
        }
      })

      attrs = json_model_class.attribute_types
      expect(attrs.key?("meta")).to be true

      ActiveRecord::Base.connection.drop_table("vca_jsons", if_exists: true)
    end
  end

  describe "loaded-tracking infrastructure" do
    let!(:setup) do
      build_model("vca_track", {
        "name" => "vca_track",
        "fields" => [
          { "name" => "title", "type" => "string" }
        ],
        "associations" => [
          { "type" => "has_many", "name" => "vca_track_items", "target_model" => "vca_track_item", "foreign_key" => "vca_track_id" }
        ],
        "virtual_columns" => {
          "items_count" => { "function" => "count", "association" => "vca_track_items" }
        }
      })
    end

    let!(:item_setup) do
      build_model("vca_track_item", {
        "name" => "vca_track_item",
        "fields" => [
          { "name" => "name", "type" => "string" },
          { "name" => "vca_track_id", "type" => "integer" }
        ]
      })
    end

    let(:model_class) { setup[1] }
    let(:model_def) { setup[0] }

    after(:all) do
      conn = ActiveRecord::Base.connection
      conn.drop_table("vca_tracks", if_exists: true)
      conn.drop_table("vca_track_items", if_exists: true)
    end

    it "installs thread_mattr_accessor _virtual_columns_stack" do
      expect(model_class).to respond_to(:_virtual_columns_stack)
      expect(model_class).to respond_to(:_virtual_columns_stack=)
    end

    it "installs after_initialize callback that tracks loaded VCs" do
      record = model_class.create!(title: "Test")

      # Load via Builder with VC
      scope = model_class.where(id: record.id)
      scope, _ = LcpRuby::VirtualColumns::Builder.apply(scope, model_def, [ "items_count" ])
      loaded = scope.first

      expect(loaded.virtual_column_loaded?("items_count")).to be true
      expect(loaded.virtual_column_loaded?("other_vc")).to be false
    end

    it "tracks empty set for records loaded without VCs" do
      record = model_class.create!(title: "Plain")
      reloaded = model_class.find(record.id)

      expect(reloaded.virtual_column_loaded?("items_count")).to be false
    end

    it "clears tracking on reload" do
      record = model_class.create!(title: "Reload Test")
      scope = model_class.where(id: record.id)
      scope, _ = LcpRuby::VirtualColumns::Builder.apply(scope, model_def, [ "items_count" ])
      loaded = scope.first

      expect(loaded.virtual_column_loaded?("items_count")).to be true

      loaded.reload
      expect(loaded.virtual_column_loaded?("items_count")).to be false
    end

    it "returns true for new records (no tracking)" do
      record = model_class.new(title: "New")
      expect(record.virtual_column_loaded?("items_count")).to be true
    end
  end

  describe "service validation" do
    it "raises when service not found in any registry" do
      expect {
        build_model("vca_bad_svc", {
          "name" => "vca_bad_svc",
          "fields" => [ { "name" => "title", "type" => "string" } ],
          "virtual_columns" => {
            "missing" => { "service" => "nonexistent_service", "type" => "integer" }
          }
        })
      }.to raise_error(LcpRuby::MetadataError, /service 'nonexistent_service' not found/)
    end

    it "accepts services registered in aggregates category (fallback)" do
      svc = double("aggregate_service")
      LcpRuby::Services::Registry.register("aggregates", "legacy_svc", svc)

      expect {
        build_model("vca_legacy_svc", {
          "name" => "vca_legacy_svc",
          "fields" => [ { "name" => "title", "type" => "string" } ],
          "virtual_columns" => {
            "legacy" => { "service" => "legacy_svc", "type" => "integer" }
          }
        })
      }.not_to raise_error

      ActiveRecord::Base.connection.drop_table("vca_legacy_svcs", if_exists: true)
    end
  end
end
