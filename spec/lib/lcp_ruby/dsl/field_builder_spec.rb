require "spec_helper"

RSpec.describe LcpRuby::Dsl::FieldBuilder do
  describe "#validates" do
    it "collects a simple validation" do
      builder = described_class.new
      builder.validates(:presence)

      expect(builder.validations.length).to eq(1)
      expect(builder.validations.first).to eq({ "type" => "presence" })
    end

    it "collects validation with options" do
      builder = described_class.new
      builder.validates(:length, minimum: 3, maximum: 255)

      validation = builder.validations.first
      expect(validation["type"]).to eq("length")
      expect(validation["options"]).to eq({ "minimum" => 3, "maximum" => 255 })
    end

    it "extracts validator_class separately" do
      builder = described_class.new
      builder.validates(:custom, validator_class: "MyValidator", param: "val")

      validation = builder.validations.first
      expect(validation["type"]).to eq("custom")
      expect(validation["validator_class"]).to eq("MyValidator")
      expect(validation["options"]).to eq({ "param" => "val" })
    end

    it "omits options key when no options provided" do
      builder = described_class.new
      builder.validates(:presence)

      expect(builder.validations.first).not_to have_key("options")
    end

    it "collects multiple validations" do
      builder = described_class.new
      builder.validates(:presence)
      builder.validates(:length, minimum: 1)

      expect(builder.validations.length).to eq(2)
    end
  end
end
