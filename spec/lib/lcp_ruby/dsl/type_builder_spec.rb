require "spec_helper"

RSpec.describe LcpRuby::Dsl::TypeBuilder do
  describe "#to_hash" do
    it "builds a complete type hash" do
      builder = described_class.new(:currency)
      builder.instance_eval do
        base_type :decimal
        column_option :precision, 12
        column_option :scale, 2
        transform :strip
        validate :numericality, greater_than_or_equal_to: 0
        input_type :number
        renderer :currency
        html_attr :step, "0.01"
      end

      hash = builder.to_hash
      expect(hash["name"]).to eq("currency")
      expect(hash["base_type"]).to eq("decimal")
      expect(hash["transforms"]).to eq([ "strip" ])
      expect(hash["validations"]).to eq([
        { "type" => "numericality", "options" => { "greater_than_or_equal_to" => 0 } }
      ])
      expect(hash["input_type"]).to eq("number")
      expect(hash["renderer"]).to eq("currency")
      expect(hash["column_options"]).to eq("precision" => 12, "scale" => 2)
      expect(hash["html_input_attrs"]).to eq("step" => "0.01")
    end

    it "builds a minimal type hash" do
      builder = described_class.new(:simple)
      builder.instance_eval do
        base_type :string
      end

      hash = builder.to_hash
      expect(hash["name"]).to eq("simple")
      expect(hash["base_type"]).to eq("string")
      expect(hash).not_to have_key("transforms")
      expect(hash).not_to have_key("validations")
      expect(hash).not_to have_key("input_type")
      expect(hash).not_to have_key("renderer")
    end

    it "accumulates multiple transforms" do
      builder = described_class.new(:email)
      builder.instance_eval do
        base_type :string
        transform :strip
        transform :downcase
      end

      expect(builder.to_hash["transforms"]).to eq(%w[strip downcase])
    end

    it "accumulates multiple validations" do
      builder = described_class.new(:bounded)
      builder.instance_eval do
        base_type :integer
        validate :presence
        validate :numericality, greater_than: 0
      end

      validations = builder.to_hash["validations"]
      expect(validations.size).to eq(2)
      expect(validations[0]["type"]).to eq("presence")
      expect(validations[1]["type"]).to eq("numericality")
    end
  end

  describe "round-trip via TypeDefinition" do
    it "produces a valid TypeDefinition from DSL" do
      builder = described_class.new(:email)
      builder.instance_eval do
        base_type :string
        transform :strip
        transform :downcase
        validate :format, with: '\A.+@.+\z'
        input_type :email
        renderer :email_link
        column_option :limit, 255
      end

      type_def = LcpRuby::Types::TypeDefinition.from_hash(builder.to_hash)
      expect(type_def.name).to eq("email")
      expect(type_def.base_type).to eq("string")
      expect(type_def.column_type).to eq(:string)
      expect(type_def.transforms).to eq(%w[strip downcase])
      expect(type_def.column_options[:limit]).to eq(255)
    end
  end
end
