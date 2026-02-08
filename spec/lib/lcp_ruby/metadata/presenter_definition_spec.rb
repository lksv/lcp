require "spec_helper"

RSpec.describe LcpRuby::Metadata::PresenterDefinition do
  let(:fixtures_path) { File.expand_path("../../../fixtures/metadata", __dir__) }

  describe ".from_hash" do
    let(:hash) do
      YAML.safe_load_file(File.join(fixtures_path, "presenters/project_admin.yml"))["presenter"]
    end

    subject(:presenter) { described_class.from_hash(hash) }

    it "parses name and model" do
      expect(presenter.name).to eq("project_admin")
      expect(presenter.model).to eq("project")
    end

    it "parses slug" do
      expect(presenter.slug).to eq("projects")
      expect(presenter.routable?).to be true
    end

    it "parses index configuration" do
      expect(presenter.default_view).to eq("table")
      expect(presenter.per_page).to eq(25)
      expect(presenter.table_columns).to be_an(Array)
      expect(presenter.table_columns.length).to eq(4)
    end

    it "parses actions" do
      expect(presenter.collection_actions).to be_an(Array)
      expect(presenter.single_actions.length).to be >= 3
    end

    it "is not read-only by default" do
      expect(presenter.read_only?).to be false
    end
  end

  describe "read-only presenter" do
    let(:hash) do
      YAML.safe_load_file(File.join(fixtures_path, "presenters/project_public.yml"))["presenter"]
    end

    subject(:presenter) { described_class.from_hash(hash) }

    it "is read-only" do
      expect(presenter.read_only?).to be true
    end

    it "has a different slug" do
      expect(presenter.slug).to eq("public-projects")
    end
  end

  describe "validation" do
    it "raises on missing name" do
      expect {
        described_class.from_hash("model" => "project")
      }.to raise_error(LcpRuby::MetadataError, /name is required/)
    end

    it "raises on missing model" do
      expect {
        described_class.from_hash("name" => "test")
      }.to raise_error(LcpRuby::MetadataError, /requires a model/)
    end
  end
end
