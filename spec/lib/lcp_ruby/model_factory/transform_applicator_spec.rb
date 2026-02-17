require "spec_helper"

RSpec.describe LcpRuby::ModelFactory::TransformApplicator do
  before do
    LcpRuby::Types::BuiltInServices.register_all!
    LcpRuby::Types::BuiltInTypes.register_all!
    LcpRuby::Services::BuiltInTransforms.register_all!
  end

  after do
    ActiveRecord::Base.connection.drop_table(:contacts) if ActiveRecord::Base.connection.table_exists?(:contacts)
  end

  def build_model(model_hash)
    model_definition = LcpRuby::Metadata::ModelDefinition.from_hash(model_hash)
    LcpRuby::ModelFactory::SchemaManager.new(model_definition).ensure_table!

    model_class = Class.new(ActiveRecord::Base) do
      self.table_name = model_definition.table_name
    end
    LcpRuby::Dynamic.const_set(:Contact, model_class)

    described_class.new(model_class, model_definition).apply!
    model_class
  end

  describe "#apply! with type-level transforms" do
    let(:model_hash) do
      {
        "name" => "contact",
        "fields" => [
          { "name" => "email", "type" => "email" },
          { "name" => "name", "type" => "string" }
        ],
        "options" => { "timestamps" => false }
      }
    end

    it "applies normalizes to fields with type_definition transforms" do
      model_class = build_model(model_hash)

      record = model_class.new(email: "  FOO@BAR.COM  ")
      expect(record.email).to eq("foo@bar.com")
    end

    it "does not apply transforms to base-type fields" do
      model_class = build_model(model_hash)

      record = model_class.new(name: "  Hello  ")
      expect(record.name).to eq("  Hello  ")
    end
  end

  describe "#apply! with field-level transforms" do
    let(:model_hash) do
      {
        "name" => "contact",
        "fields" => [
          { "name" => "email", "type" => "string", "transforms" => [ "strip" ] },
          { "name" => "name", "type" => "string" }
        ],
        "options" => { "timestamps" => false }
      }
    end

    it "applies field-level transforms" do
      model_class = build_model(model_hash)

      record = model_class.new(email: "  hello@test.com  ")
      expect(record.email).to eq("hello@test.com")
    end

    it "does not apply transforms to fields without transforms" do
      model_class = build_model(model_hash)

      record = model_class.new(name: "  Hello  ")
      expect(record.name).to eq("  Hello  ")
    end
  end

  describe "#apply! merging type-level and field-level transforms" do
    let(:model_hash) do
      {
        "name" => "contact",
        "fields" => [
          # email type already has strip+downcase; adding strip again should deduplicate
          { "name" => "email", "type" => "email", "transforms" => [ "strip" ] },
          { "name" => "name", "type" => "string" }
        ],
        "options" => { "timestamps" => false }
      }
    end

    it "deduplicates transforms when field repeats type transforms" do
      model_class = build_model(model_hash)

      record = model_class.new(email: "  FOO@BAR.COM  ")
      expect(record.email).to eq("foo@bar.com")
    end
  end

  describe "#apply! with service registry fallback" do
    let(:model_hash) do
      {
        "name" => "contact",
        "fields" => [
          { "name" => "name", "type" => "string", "transforms" => [ "strip" ] }
        ],
        "options" => { "timestamps" => false }
      }
    end

    it "resolves transforms from unified Services::Registry" do
      model_class = build_model(model_hash)

      record = model_class.new(name: "  Hello  ")
      expect(record.name).to eq("Hello")
    end
  end
end
