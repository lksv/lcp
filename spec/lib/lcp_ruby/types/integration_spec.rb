require "spec_helper"

RSpec.describe "Type Registry Integration" do
  before do
    LcpRuby::Types::BuiltInTypes.register_all!
    LcpRuby::Services::BuiltInTransforms.register_all!
  end

  let(:model_hash) do
    {
      "name" => "contact",
      "fields" => [
        { "name" => "name", "type" => "string" },
        { "name" => "email", "type" => "email" },
        { "name" => "phone", "type" => "phone" },
        { "name" => "website", "type" => "url" },
        { "name" => "favorite_color", "type" => "color" }
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

  describe "field definition with custom types" do
    it "resolves type_definition for email field" do
      email_field = model_definition.fields.find { |f| f.name == "email" }
      expect(email_field.type_definition).to be_a(LcpRuby::Types::TypeDefinition)
      expect(email_field.type_definition.name).to eq("email")
    end

    it "returns nil type_definition for base-type fields" do
      name_field = model_definition.fields.find { |f| f.name == "name" }
      expect(name_field.type_definition).to be_nil
    end

    it "delegates column_type through type_definition" do
      email_field = model_definition.fields.find { |f| f.name == "email" }
      expect(email_field.column_type).to eq(:string)
    end
  end

  describe "database column" do
    it "creates string column for email type" do
      columns = ActiveRecord::Base.connection.columns(:contacts)
      email_col = columns.find { |c| c.name == "email" }

      expect(email_col).not_to be_nil
      expect(email_col.type).to eq(:string)
    end

    it "applies type-level column limit" do
      columns = ActiveRecord::Base.connection.columns(:contacts)
      email_col = columns.find { |c| c.name == "email" }
      expect(email_col.limit).to eq(255)
    end
  end

  describe "model building with transforms and validations" do
    subject(:model_class) { LcpRuby::ModelFactory::Builder.new(model_definition).build }

    it "normalizes email: strips and downcases" do
      record = model_class.new(email: "  FOO@BAR.COM  ")
      expect(record.email).to eq("foo@bar.com")
    end

    it "normalizes phone: strips non-digits, preserves leading +" do
      record = model_class.new(phone: "+1 (555) 123-4567")
      expect(record.phone).to eq("+15551234567")
    end

    it "normalizes url: prepends https:// if no scheme" do
      record = model_class.new(website: "example.com")
      expect(record.website).to eq("https://example.com")
    end

    it "normalizes url: preserves existing scheme" do
      record = model_class.new(website: "http://example.com")
      expect(record.website).to eq("http://example.com")
    end

    it "normalizes color: strips and downcases" do
      record = model_class.new(favorite_color: "  #FF00AA  ")
      expect(record.favorite_color).to eq("#ff00aa")
    end

    it "applies format validation from type definition" do
      record = model_class.new(name: "Test", email: "not-an-email")
      record.valid?
      expect(record.errors[:email]).not_to be_empty
    end

    it "passes validation with valid email" do
      record = model_class.new(name: "Test", email: "user@example.com")
      record.valid?
      expect(record.errors[:email]).to be_empty
    end

    it "applies format validation for color" do
      record = model_class.new(name: "Test", favorite_color: "red")
      record.valid?
      expect(record.errors[:favorite_color]).not_to be_empty
    end

    it "passes validation with valid color" do
      record = model_class.new(name: "Test", favorite_color: "#ff0000")
      record.valid?
      expect(record.errors[:favorite_color]).to be_empty
    end
  end

  describe "model with additional field-level validations" do
    let(:model_hash_with_presence) do
      {
        "name" => "contact_required",
        "table_name" => "contacts",
        "fields" => [
          { "name" => "name", "type" => "string" },
          {
            "name" => "email",
            "type" => "email",
            "validations" => [
              { "type" => "presence" }
            ]
          }
        ],
        "options" => { "timestamps" => false }
      }
    end
    let(:model_def) { LcpRuby::Metadata::ModelDefinition.from_hash(model_hash_with_presence) }

    it "merges field-level validations with type-default validations" do
      model_class = LcpRuby::ModelFactory::Builder.new(model_def).build

      # Should have presence (from field) + format (from type)
      record = model_class.new(email: nil)
      record.valid?
      expect(record.errors[:email]).to include("can't be blank")

      record2 = model_class.new(email: "not-valid")
      record2.valid?
      expect(record2.errors[:email]).not_to be_empty
    end

    it "does not duplicate validations when field overrides type default" do
      hash_with_custom_format = {
        "name" => "contact_custom_format",
        "table_name" => "contacts",
        "fields" => [
          { "name" => "name", "type" => "string" },
          {
            "name" => "email",
            "type" => "email",
            "validations" => [
              { "type" => "format", "options" => { "with" => '\A.+@company\.com\z' } }
            ]
          }
        ],
        "options" => { "timestamps" => false }
      }
      model_def = LcpRuby::Metadata::ModelDefinition.from_hash(hash_with_custom_format)
      model_class = LcpRuby::ModelFactory::Builder.new(model_def).build

      # The field's own format should take precedence; type-default format is skipped
      record = model_class.new(email: "user@other.com")
      record.valid?
      expect(record.errors[:email]).not_to be_empty

      record2 = model_class.new(email: "user@company.com")
      record2.valid?
      expect(record2.errors[:email]).to be_empty
    end
  end

  describe "YAML type definition loading" do
    it "loads a custom type from YAML and uses it in a model" do
      # Simulate custom type registration from YAML
      type_hash = {
        "name" => "currency",
        "base_type" => "decimal",
        "column_options" => { "precision" => 12, "scale" => 2 },
        "transforms" => [ "strip" ],
        "validations" => [
          { "type" => "numericality", "options" => { "greater_than_or_equal_to" => 0 } }
        ],
        "input_type" => "number",
        "display_type" => "currency"
      }

      type_def = LcpRuby::Types::TypeDefinition.from_hash(type_hash)
      LcpRuby::Types::TypeRegistry.register("currency", type_def)

      model_hash = {
        "name" => "invoice",
        "fields" => [
          { "name" => "amount", "type" => "currency" }
        ],
        "options" => { "timestamps" => false }
      }
      model_def = LcpRuby::Metadata::ModelDefinition.from_hash(model_hash)

      LcpRuby::ModelFactory::SchemaManager.new(model_def).ensure_table!
      model_class = LcpRuby::ModelFactory::Builder.new(model_def).build

      # Verify column type
      columns = ActiveRecord::Base.connection.columns(:invoices)
      amount_col = columns.find { |c| c.name == "amount" }
      expect(amount_col.type).to eq(:decimal)
      expect(amount_col.precision).to eq(12)
      expect(amount_col.scale).to eq(2)

      # Verify validation
      record = model_class.new(amount: -5)
      record.valid?
      expect(record.errors[:amount]).not_to be_empty

      record2 = model_class.new(amount: 100.50)
      record2.valid?
      expect(record2.errors[:amount]).to be_empty
    ensure
      ActiveRecord::Base.connection.drop_table(:invoices) if ActiveRecord::Base.connection.table_exists?(:invoices)
    end
  end

  describe "DSL type definition" do
    it "defines and uses a type via DSL convenience method" do
      LcpRuby.define_type :percentage do
        base_type :integer
        transform :strip
        validate :numericality, greater_than_or_equal_to: 0, less_than_or_equal_to: 100
        input_type :number
        display_type :percentage
      end

      expect(LcpRuby::Types::TypeRegistry.registered?("percentage")).to be true
      type_def = LcpRuby::Types::TypeRegistry.resolve("percentage")
      expect(type_def.base_type).to eq("integer")
      expect(type_def.input_type).to eq("number")
    end
  end
end
