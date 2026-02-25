require "spec_helper"

RSpec.describe LcpRuby::Metadata::GroupDefinition do
  describe ".from_hash" do
    it "parses a complete hash" do
      hash = {
        "name" => "sales_team",
        "label" => "Sales Team",
        "description" => "Sales department",
        "roles" => %w[sales_rep viewer]
      }

      definition = described_class.from_hash(hash)

      expect(definition.name).to eq("sales_team")
      expect(definition.label).to eq("Sales Team")
      expect(definition.description).to eq("Sales department")
      expect(definition.roles).to eq(%w[sales_rep viewer])
    end

    it "handles symbol keys" do
      hash = { name: "admins", roles: %w[admin] }

      definition = described_class.from_hash(hash)

      expect(definition.name).to eq("admins")
      expect(definition.roles).to eq(%w[admin])
    end

    it "defaults label to titleized name" do
      definition = described_class.from_hash("name" => "it_admins")
      expect(definition.label).to eq("It Admins")
    end

    it "defaults roles to empty array" do
      definition = described_class.from_hash("name" => "empty_group")
      expect(definition.roles).to eq([])
    end

    it "defaults description to nil" do
      definition = described_class.from_hash("name" => "test")
      expect(definition.description).to be_nil
    end

    it "raises MetadataError when name is nil" do
      expect {
        described_class.from_hash("label" => "No Name")
      }.to raise_error(LcpRuby::MetadataError, /must have a 'name' key/)
    end

    it "raises MetadataError when name is blank" do
      expect {
        described_class.from_hash("name" => "  ")
      }.to raise_error(LcpRuby::MetadataError, /must have a 'name' key/)
    end

    it "wraps a single string role into an array" do
      definition = described_class.from_hash("name" => "test", "roles" => "admin")
      expect(definition.roles).to eq(%w[admin])
    end
  end
end
