require "spec_helper"

RSpec.describe LcpRuby::JsonItemWrapper do
  let(:model_definition) do
    LcpRuby::Metadata::ModelDefinition.from_hash({
      "name" => "test_item",
      "table_name" => "_virtual",
      "fields" => [
        { "name" => "name", "type" => "string", "validations" => [ { "type" => "presence" } ] },
        { "name" => "quantity", "type" => "integer" },
        { "name" => "price", "type" => "float" },
        { "name" => "active", "type" => "boolean" },
        { "name" => "notes", "type" => "text" }
      ]
    })
  end

  describe "#initialize" do
    it "accepts a hash and model definition" do
      wrapper = described_class.new({ "name" => "Widget" }, model_definition)
      expect(wrapper.name).to eq("Widget")
    end

    it "works without a model definition" do
      wrapper = described_class.new({ "name" => "Widget" })
      expect(wrapper.name).to eq("Widget")
    end

    it "handles nil data" do
      wrapper = described_class.new(nil, model_definition)
      expect(wrapper.name).to be_nil
    end

    it "normalizes string keys" do
      wrapper = described_class.new({ name: "Widget" }, model_definition)
      expect(wrapper.name).to eq("Widget")
    end
  end

  describe "dynamic accessors" do
    it "defines getters for all model fields" do
      wrapper = described_class.new({ "name" => "Widget", "quantity" => "5" }, model_definition)
      expect(wrapper.name).to eq("Widget")
      expect(wrapper.quantity).to eq(5)
    end

    it "defines setters for all model fields" do
      wrapper = described_class.new({}, model_definition)
      wrapper.name = "New Name"
      expect(wrapper.name).to eq("New Name")
    end

    it "coerces integer values" do
      wrapper = described_class.new({ "quantity" => "42" }, model_definition)
      expect(wrapper.quantity).to eq(42)
    end

    it "coerces float values" do
      wrapper = described_class.new({ "price" => "9.99" }, model_definition)
      expect(wrapper.price).to eq(9.99)
    end

    it "coerces boolean values" do
      wrapper = described_class.new({ "active" => "1" }, model_definition)
      expect(wrapper.active).to eq(true)

      wrapper2 = described_class.new({ "active" => "0" }, model_definition)
      expect(wrapper2.active).to eq(false)
    end

    it "returns nil for blank numeric values" do
      wrapper = described_class.new({ "quantity" => "" }, model_definition)
      expect(wrapper.quantity).to be_nil
    end
  end

  describe "#to_hash" do
    it "returns the underlying data as a hash" do
      data = { "name" => "Widget", "quantity" => "5" }
      wrapper = described_class.new(data, model_definition)
      expect(wrapper.to_hash).to eq(data)
    end

    it "reflects setter changes" do
      wrapper = described_class.new({ "name" => "Old" }, model_definition)
      wrapper.name = "New"
      expect(wrapper.to_hash["name"]).to eq("New")
    end
  end

  describe "#validate_with_model_rules!" do
    it "returns true when all validations pass" do
      wrapper = described_class.new({ "name" => "Widget" }, model_definition)
      expect(wrapper.validate_with_model_rules!).to be true
    end

    it "adds errors when presence validation fails" do
      wrapper = described_class.new({ "name" => "" }, model_definition)
      wrapper.validate_with_model_rules!
      expect(wrapper.errors[:name]).to include("can't be blank")
    end

    it "adds errors when name is nil" do
      wrapper = described_class.new({}, model_definition)
      wrapper.validate_with_model_rules!
      expect(wrapper.errors[:name]).to include("can't be blank")
    end

    it "returns true without model definition" do
      wrapper = described_class.new({ "name" => "" })
      expect(wrapper.validate_with_model_rules!).to be true
    end
  end

  describe "#respond_to_missing?" do
    it "responds to model field names" do
      wrapper = described_class.new({}, model_definition)
      expect(wrapper.respond_to?(:name)).to be true
      expect(wrapper.respond_to?(:quantity)).to be true
    end

    it "responds to setter methods" do
      wrapper = described_class.new({})
      expect(wrapper.respond_to?(:foo=)).to be true
    end

    it "responds to keys in the data hash without model def" do
      wrapper = described_class.new({ "custom" => "val" })
      expect(wrapper.respond_to?(:custom)).to be true
    end
  end

  describe "length validation" do
    let(:length_model) do
      LcpRuby::Metadata::ModelDefinition.from_hash({
        "name" => "length_test",
        "table_name" => "_virtual",
        "fields" => [
          {
            "name" => "code",
            "type" => "string",
            "validations" => [ { "type" => "length", "options" => { "minimum" => 2, "maximum" => 5 } } ]
          }
        ]
      })
    end

    it "validates minimum length" do
      wrapper = described_class.new({ "code" => "a" }, length_model)
      wrapper.validate_with_model_rules!
      expect(wrapper.errors[:code]).to be_present
    end

    it "validates maximum length" do
      wrapper = described_class.new({ "code" => "toolong" }, length_model)
      wrapper.validate_with_model_rules!
      expect(wrapper.errors[:code]).to be_present
    end

    it "passes when length is in range" do
      wrapper = described_class.new({ "code" => "abc" }, length_model)
      expect(wrapper.validate_with_model_rules!).to be true
    end
  end
end
