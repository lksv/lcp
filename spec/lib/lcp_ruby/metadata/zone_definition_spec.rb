require "spec_helper"

RSpec.describe LcpRuby::Metadata::ZoneDefinition do
  describe ".new" do
    it "creates a zone with required attributes" do
      zone = described_class.new(name: "main", presenter: "contacts")
      expect(zone.name).to eq("main")
      expect(zone.presenter).to eq("contacts")
      expect(zone.area).to eq("main")
    end

    it "defaults area to main" do
      zone = described_class.new(name: "sidebar", presenter: "contacts")
      expect(zone.area).to eq("main")
    end

    it "accepts a custom area" do
      zone = described_class.new(name: "sidebar", presenter: "contacts", area: "sidebar")
      expect(zone.area).to eq("sidebar")
    end

    it "raises when name is blank" do
      expect {
        described_class.new(name: "", presenter: "contacts")
      }.to raise_error(LcpRuby::MetadataError, /Zone name is required/)
    end

    it "raises when presenter is blank" do
      expect {
        described_class.new(name: "main", presenter: "")
      }.to raise_error(LcpRuby::MetadataError, /requires a presenter reference/)
    end
  end

  describe ".from_hash" do
    it "parses a hash" do
      zone = described_class.from_hash("name" => "main", "presenter" => "contacts", "area" => "sidebar")
      expect(zone.name).to eq("main")
      expect(zone.presenter).to eq("contacts")
      expect(zone.area).to eq("sidebar")
    end

    it "handles symbol keys" do
      zone = described_class.from_hash(name: "main", presenter: "contacts")
      expect(zone.name).to eq("main")
      expect(zone.presenter).to eq("contacts")
    end
  end
end
