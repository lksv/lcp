require "spec_helper"

RSpec.describe LcpRuby::Pages::Resolver do
  let(:fixtures_path) { File.expand_path("../../../fixtures/metadata", __dir__) }

  before do
    LcpRuby.reset!
    LcpRuby.configuration.metadata_path = fixtures_path
    LcpRuby.loader.load_all
  end

  describe ".find_by_slug" do
    it "finds a page by slug" do
      page = described_class.find_by_slug("projects")
      expect(page).to be_a(LcpRuby::Metadata::PageDefinition)
      expect(page.slug).to eq("projects")
    end

    it "raises when slug not found" do
      expect {
        described_class.find_by_slug("nonexistent")
      }.to raise_error(LcpRuby::MetadataError, /No page found/)
    end

    it "returns an auto-generated page" do
      page = described_class.find_by_slug("projects")
      expect(page.auto_generated?).to be true
      expect(page.main_presenter_name).to eq("project")
    end
  end

  describe ".find_by_name" do
    it "finds a page by name" do
      page = described_class.find_by_name("project")
      expect(page.name).to eq("project")
    end

    it "raises when name not found" do
      expect {
        described_class.find_by_name("nonexistent")
      }.to raise_error(LcpRuby::MetadataError)
    end
  end

  describe ".routable_pages" do
    it "returns only pages with slugs" do
      pages = described_class.routable_pages
      expect(pages).to all(satisfy { |p| p.slug.present? })
    end
  end
end
