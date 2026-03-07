require "spec_helper"

RSpec.describe LcpRuby::Metadata::PageDefinition do
  let(:main_zone) { LcpRuby::Metadata::ZoneDefinition.new(name: "main", presenter: "contacts") }

  describe ".new" do
    it "creates a page with required attributes" do
      page = described_class.new(name: "contacts_page", zones: [ main_zone ])
      expect(page.name).to eq("contacts_page")
      expect(page.zones.length).to eq(1)
      expect(page.main_zone).to eq(main_zone)
    end

    it "defaults auto_generated to false" do
      page = described_class.new(name: "contacts_page", zones: [ main_zone ])
      expect(page.auto_generated?).to be false
    end

    it "accepts optional attributes" do
      page = described_class.new(
        name: "contacts_page",
        model: "contact",
        slug: "contacts",
        dialog_config: { "size" => "large" },
        zones: [ main_zone ],
        auto_generated: true
      )
      expect(page.model).to eq("contact")
      expect(page.slug).to eq("contacts")
      expect(page.dialog_size).to eq("large")
      expect(page.auto_generated?).to be true
    end

    it "raises when name is blank" do
      expect {
        described_class.new(name: "", zones: [ main_zone ])
      }.to raise_error(LcpRuby::MetadataError, /Page name is required/)
    end

    it "raises when zones are empty" do
      expect {
        described_class.new(name: "test", zones: [])
      }.to raise_error(LcpRuby::MetadataError, /must have at least one zone/)
    end
  end

  describe "#routable?" do
    it "returns true when slug is present" do
      page = described_class.new(name: "test", slug: "contacts", zones: [ main_zone ])
      expect(page.routable?).to be true
    end

    it "returns false when slug is nil" do
      page = described_class.new(name: "test", zones: [ main_zone ])
      expect(page.routable?).to be false
    end
  end

  describe "#dialog_only?" do
    it "returns true when no slug but dialog config present" do
      page = described_class.new(
        name: "test",
        dialog_config: { "size" => "small" },
        zones: [ main_zone ]
      )
      expect(page.dialog_only?).to be true
    end

    it "returns false when slug is present" do
      page = described_class.new(
        name: "test",
        slug: "contacts",
        dialog_config: { "size" => "small" },
        zones: [ main_zone ]
      )
      expect(page.dialog_only?).to be false
    end

    it "returns false when no dialog config" do
      page = described_class.new(name: "test", zones: [ main_zone ])
      expect(page.dialog_only?).to be false
    end
  end

  describe "#main_zone" do
    it "returns the zone with area main" do
      sidebar_zone = LcpRuby::Metadata::ZoneDefinition.new(name: "side", presenter: "sidebar", area: "sidebar")
      page = described_class.new(name: "test", zones: [ sidebar_zone, main_zone ])
      expect(page.main_zone).to eq(main_zone)
    end

    it "returns first zone when no main area" do
      zone1 = LcpRuby::Metadata::ZoneDefinition.new(name: "a", presenter: "p1", area: "sidebar")
      zone2 = LcpRuby::Metadata::ZoneDefinition.new(name: "b", presenter: "p2", area: "sidebar")
      page = described_class.new(name: "test", zones: [ zone1, zone2 ])
      expect(page.main_zone).to eq(zone1)
    end
  end

  describe "#main_presenter_name" do
    it "returns the main zone presenter" do
      page = described_class.new(name: "test", zones: [ main_zone ])
      expect(page.main_presenter_name).to eq("contacts")
    end
  end

  describe "dialog defaults" do
    it "defaults dialog_size to medium" do
      page = described_class.new(name: "test", zones: [ main_zone ])
      expect(page.dialog_size).to eq("medium")
    end

    it "defaults dialog_closable? to true" do
      page = described_class.new(name: "test", zones: [ main_zone ])
      expect(page.dialog_closable?).to be true
    end

    it "reads dialog_closable? from config" do
      page = described_class.new(name: "test", dialog_config: { "closable" => false }, zones: [ main_zone ])
      expect(page.dialog_closable?).to be false
    end

    it "reads dialog_title_key from config" do
      page = described_class.new(name: "test", dialog_config: { "title_key" => "my.title" }, zones: [ main_zone ])
      expect(page.dialog_title_key).to eq("my.title")
    end
  end

  describe ".from_hash" do
    it "parses a hash with zones" do
      page = described_class.from_hash(
        "name" => "contacts_page",
        "model" => "contact",
        "slug" => "contacts",
        "dialog" => { "size" => "large" },
        "zones" => [
          { "name" => "main", "presenter" => "contacts" }
        ]
      )
      expect(page.name).to eq("contacts_page")
      expect(page.model).to eq("contact")
      expect(page.slug).to eq("contacts")
      expect(page.dialog_size).to eq("large")
      expect(page.zones.length).to eq(1)
      expect(page.zones.first.presenter).to eq("contacts")
    end
  end
end
