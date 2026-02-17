require "spec_helper"

RSpec.describe LcpRuby::ModelFactory::DefaultApplicator do
  before do
    LcpRuby::Types::BuiltInServices.register_all!
    LcpRuby::Types::BuiltInTypes.register_all!
    LcpRuby::Services::BuiltInTransforms.register_all!
    LcpRuby::Services::BuiltInDefaults.register_all!
  end

  after do
    ActiveRecord::Base.connection.drop_table(:items) if ActiveRecord::Base.connection.table_exists?(:items)
  end

  def build_full_model(model_hash)
    model_definition = LcpRuby::Metadata::ModelDefinition.from_hash(model_hash)
    LcpRuby::ModelFactory::SchemaManager.new(model_definition).ensure_table!

    builder = LcpRuby::ModelFactory::Builder.new(model_definition)
    builder.build
  end

  describe "built-in dynamic defaults" do
    let(:model_hash) do
      {
        "name" => "item",
        "fields" => [
          { "name" => "title", "type" => "string" },
          { "name" => "start_date", "type" => "date", "default" => "current_date" }
        ],
        "options" => { "timestamps" => false }
      }
    end

    it "sets current_date default on new records" do
      model_class = build_full_model(model_hash)
      record = model_class.new(title: "Test")
      expect(record.start_date).to eq(Date.today)
    end

    it "does not override explicitly set values" do
      model_class = build_full_model(model_hash)
      custom_date = Date.today + 5
      record = model_class.new(title: "Test", start_date: custom_date)
      expect(record.start_date).to eq(custom_date)
    end

    it "does not apply to persisted records" do
      model_class = build_full_model(model_hash)
      record = model_class.create!(title: "Test")
      record.update!(start_date: nil)
      record.reload
      expect(record.start_date).to be_nil
    end
  end

  describe "service-based dynamic defaults" do
    let(:model_hash) do
      {
        "name" => "item",
        "fields" => [
          { "name" => "title", "type" => "string" },
          { "name" => "due_date", "type" => "date", "default" => { "service" => "one_week_out" } }
        ],
        "options" => { "timestamps" => false }
      }
    end

    it "calls the service to set default" do
      service = Class.new do
        def self.call(record, field_name)
          Date.today + 7
        end
      end
      LcpRuby::Services::Registry.register("defaults", "one_week_out", service)

      model_class = build_full_model(model_hash)
      record = model_class.new(title: "Test")
      expect(record.due_date).to eq(Date.today + 7)
    end

    it "does not override explicitly set values" do
      service = Class.new do
        def self.call(record, field_name)
          Date.today + 7
        end
      end
      LcpRuby::Services::Registry.register("defaults", "one_week_out", service)

      model_class = build_full_model(model_hash)
      custom_date = Date.today + 30
      record = model_class.new(title: "Test", due_date: custom_date)
      expect(record.due_date).to eq(custom_date)
    end
  end

  describe "scalar defaults are not affected" do
    let(:model_hash) do
      {
        "name" => "item",
        "fields" => [
          { "name" => "title", "type" => "string" },
          { "name" => "priority", "type" => "integer", "default" => 5 }
        ],
        "options" => { "timestamps" => false }
      }
    end

    it "scalar defaults are handled by SchemaManager, not DefaultApplicator" do
      model_class = build_full_model(model_hash)
      record = model_class.new(title: "Test")
      # Scalar default is set at DB level by SchemaManager
      expect(record.priority).to eq(5)
    end
  end
end
