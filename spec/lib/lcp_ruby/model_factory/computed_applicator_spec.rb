require "spec_helper"

RSpec.describe LcpRuby::ModelFactory::ComputedApplicator do
  before do
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

  describe "template computed fields" do
    let(:model_hash) do
      {
        "name" => "item",
        "fields" => [
          { "name" => "first_name", "type" => "string" },
          { "name" => "last_name", "type" => "string" },
          { "name" => "full_name", "type" => "string", "computed" => "{first_name} {last_name}" }
        ],
        "options" => { "timestamps" => false }
      }
    end

    it "computes template field before save" do
      model_class = build_full_model(model_hash)
      record = model_class.create!(first_name: "John", last_name: "Doe")
      expect(record.full_name).to eq("John Doe")
    end

    it "updates computed field on subsequent saves" do
      model_class = build_full_model(model_hash)
      record = model_class.create!(first_name: "John", last_name: "Doe")
      record.update!(last_name: "Smith")
      expect(record.full_name).to eq("John Smith")
    end

    it "handles nil values in template" do
      model_class = build_full_model(model_hash)
      record = model_class.create!(first_name: "John", last_name: nil)
      expect(record.full_name).to eq("John ")
    end
  end

  describe "service computed fields" do
    let(:model_hash) do
      {
        "name" => "item",
        "fields" => [
          { "name" => "price", "type" => "decimal" },
          { "name" => "quantity", "type" => "integer" },
          { "name" => "total", "type" => "decimal", "computed" => { "service" => "compute_total" } }
        ],
        "options" => { "timestamps" => false }
      }
    end

    it "calls service to compute field before save" do
      service = Class.new do
        def self.call(record)
          (record.price.to_f * record.quantity.to_i).round(2)
        end
      end
      LcpRuby::Services::Registry.register("computed", "compute_total", service)

      model_class = build_full_model(model_hash)
      record = model_class.create!(price: 9.99, quantity: 3)
      expect(record.total).to eq(29.97)
    end
  end

  describe "computed field readonly in form" do
    let(:model_hash) do
      {
        "name" => "item",
        "fields" => [
          { "name" => "first_name", "type" => "string" },
          { "name" => "full_name", "type" => "string", "computed" => "{first_name}" }
        ],
        "options" => { "timestamps" => false }
      }
    end

    it "marks computed field definition as computed?" do
      model_definition = LcpRuby::Metadata::ModelDefinition.from_hash(model_hash)
      field = model_definition.field("full_name")
      expect(field.computed?).to be true
    end

    it "does not mark non-computed field as computed?" do
      model_definition = LcpRuby::Metadata::ModelDefinition.from_hash(model_hash)
      field = model_definition.field("first_name")
      expect(field.computed?).to be false
    end
  end
end
