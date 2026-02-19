require "spec_helper"

RSpec.describe LcpRuby::Types::BuiltInTypes do
  before { described_class.register_all! }

  describe ".register_all!" do
    it "registers all 4 built-in types" do
      %w[email phone url color].each do |name|
        expect(LcpRuby::Types::TypeRegistry.registered?(name)).to be true
      end
    end
  end

  describe "email type" do
    subject(:type_def) { LcpRuby::Types::TypeRegistry.resolve("email") }

    it "has correct base_type" do
      expect(type_def.base_type).to eq("string")
    end

    it "has strip and downcase transforms" do
      expect(type_def.transforms).to eq(%w[strip downcase])
    end

    it "has format validation" do
      expect(type_def.validations.first["type"]).to eq("format")
    end

    it "has email input_type" do
      expect(type_def.input_type).to eq("email")
    end

    it "has email_link renderer" do
      expect(type_def.renderer).to eq("email_link")
    end

    it "has column_options with limit 255" do
      expect(type_def.column_options[:limit]).to eq(255)
    end
  end

  describe "phone type" do
    subject(:type_def) { LcpRuby::Types::TypeRegistry.resolve("phone") }

    it "has correct base_type" do
      expect(type_def.base_type).to eq("string")
    end

    it "has strip and normalize_phone transforms" do
      expect(type_def.transforms).to eq(%w[strip normalize_phone])
    end

    it "has tel input_type" do
      expect(type_def.input_type).to eq("tel")
    end

    it "has column_options with limit 50" do
      expect(type_def.column_options[:limit]).to eq(50)
    end
  end

  describe "url type" do
    subject(:type_def) { LcpRuby::Types::TypeRegistry.resolve("url") }

    it "has correct base_type" do
      expect(type_def.base_type).to eq("string")
    end

    it "has strip and normalize_url transforms" do
      expect(type_def.transforms).to eq(%w[strip normalize_url])
    end

    it "has url input_type" do
      expect(type_def.input_type).to eq("url")
    end

    it "has column_options with limit 2048" do
      expect(type_def.column_options[:limit]).to eq(2048)
    end
  end

  describe "color type" do
    subject(:type_def) { LcpRuby::Types::TypeRegistry.resolve("color") }

    it "has correct base_type" do
      expect(type_def.base_type).to eq("string")
    end

    it "has strip and downcase transforms" do
      expect(type_def.transforms).to eq(%w[strip downcase])
    end

    it "has color input_type" do
      expect(type_def.input_type).to eq("color")
    end

    it "has column_options with limit 7" do
      expect(type_def.column_options[:limit]).to eq(7)
    end
  end
end
