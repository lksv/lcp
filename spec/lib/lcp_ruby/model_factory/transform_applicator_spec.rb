require "spec_helper"

RSpec.describe LcpRuby::ModelFactory::TransformApplicator do
  before do
    LcpRuby::Types::BuiltInServices.register_all!
    LcpRuby::Types::BuiltInTypes.register_all!
  end

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
  let(:model_definition) { LcpRuby::Metadata::ModelDefinition.from_hash(model_hash) }

  before do
    LcpRuby::ModelFactory::SchemaManager.new(model_definition).ensure_table!
  end

  after do
    ActiveRecord::Base.connection.drop_table(:contacts) if ActiveRecord::Base.connection.table_exists?(:contacts)
  end

  describe "#apply!" do
    it "applies normalizes to fields with type_definition transforms" do
      model_class = Class.new(ActiveRecord::Base) do
        self.table_name = "contacts"
      end
      LcpRuby::Dynamic.const_set(:Contact, model_class)

      described_class.new(model_class, model_definition).apply!

      # Verify that normalizes is set up (strip + downcase for email)
      record = model_class.new(email: "  FOO@BAR.COM  ")
      expect(record.email).to eq("foo@bar.com")
    end

    it "does not apply transforms to base-type fields" do
      model_class = Class.new(ActiveRecord::Base) do
        self.table_name = "contacts"
      end
      LcpRuby::Dynamic.const_set(:Contact, model_class) unless defined?(LcpRuby::Dynamic::Contact)

      described_class.new(model_class, model_definition).apply!

      # The name field (type: string) should have no transforms
      record = model_class.new(name: "  Hello  ")
      expect(record.name).to eq("  Hello  ")
    end
  end
end
