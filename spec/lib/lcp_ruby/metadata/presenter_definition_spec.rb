require "spec_helper"

RSpec.describe LcpRuby::Metadata::PresenterDefinition do
  let(:fixtures_path) { File.expand_path("../../../fixtures/metadata", __dir__) }

  describe ".from_hash" do
    let(:hash) do
      YAML.safe_load_file(File.join(fixtures_path, "presenters/project.yml"))["presenter"]
    end

    subject(:presenter) { described_class.from_hash(hash) }

    it "parses name and model" do
      expect(presenter.name).to eq("project")
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

  describe "#index_layout" do
    it "returns :table by default" do
      presenter = described_class.from_hash("name" => "test", "model" => "test")
      expect(presenter.index_layout).to eq(:table)
    end

    it "returns :tiles when layout: tiles" do
      presenter = described_class.from_hash(
        "name" => "test", "model" => "test",
        "index" => { "layout" => "tiles" }
      )
      expect(presenter.index_layout).to eq(:tiles)
      expect(presenter.tiles?).to be true
    end

    it "returns :tree when layout: tree" do
      presenter = described_class.from_hash(
        "name" => "test", "model" => "test",
        "index" => { "layout" => "tree" }
      )
      expect(presenter.index_layout).to eq(:tree)
      expect(presenter.tree_view?).to be true
    end

    it "returns :tree when tree_view: true (backward compat)" do
      presenter = described_class.from_hash(
        "name" => "test", "model" => "test",
        "index" => { "tree_view" => true }
      )
      expect(presenter.index_layout).to eq(:tree)
      expect(presenter.tree_view?).to be true
    end

    it "prefers explicit layout over tree_view flag" do
      presenter = described_class.from_hash(
        "name" => "test", "model" => "test",
        "index" => { "layout" => "tiles", "tree_view" => true }
      )
      expect(presenter.index_layout).to eq(:tiles)
    end
  end

  describe "#tile_config" do
    it "returns empty hash when not configured" do
      presenter = described_class.from_hash("name" => "test", "model" => "test")
      expect(presenter.tile_config).to eq({})
    end

    it "returns tile configuration" do
      presenter = described_class.from_hash(
        "name" => "test", "model" => "test",
        "index" => { "tile" => { "title_field" => "name", "columns" => 4 } }
      )
      expect(presenter.tile_config["title_field"]).to eq("name")
      expect(presenter.tile_config["columns"]).to eq(4)
    end
  end

  describe "#sort_fields" do
    it "returns empty array by default" do
      presenter = described_class.from_hash("name" => "test", "model" => "test")
      expect(presenter.sort_fields).to eq([])
    end

    it "returns configured sort fields" do
      presenter = described_class.from_hash(
        "name" => "test", "model" => "test",
        "index" => { "sort_fields" => [ { "field" => "name", "label" => "Name" } ] }
      )
      expect(presenter.sort_fields.length).to eq(1)
      expect(presenter.sort_fields.first["field"]).to eq("name")
    end
  end

  describe "#per_page_options" do
    it "returns nil by default" do
      presenter = described_class.from_hash("name" => "test", "model" => "test")
      expect(presenter.per_page_options).to be_nil
    end

    it "returns configured options" do
      presenter = described_class.from_hash(
        "name" => "test", "model" => "test",
        "index" => { "per_page_options" => [ 10, 25, 50 ] }
      )
      expect(presenter.per_page_options).to eq([ 10, 25, 50 ])
    end
  end

  describe "#summary_config and #summary_enabled?" do
    it "returns empty hash and false by default" do
      presenter = described_class.from_hash("name" => "test", "model" => "test")
      expect(presenter.summary_config).to eq({})
      expect(presenter.summary_enabled?).to be false
    end

    it "returns config and true when enabled" do
      presenter = described_class.from_hash(
        "name" => "test", "model" => "test",
        "index" => { "summary" => { "enabled" => true, "fields" => [ { "field" => "price", "function" => "sum" } ] } }
      )
      expect(presenter.summary_enabled?).to be true
      expect(presenter.summary_config["fields"].length).to eq(1)
    end
  end

  describe "#item_classes" do
    it "returns empty array when not configured" do
      presenter = described_class.from_hash("name" => "test", "model" => "test")
      expect(presenter.item_classes).to eq([])
    end

    it "returns configured item_classes array" do
      rules = [
        { "class" => "lcp-row-danger", "when" => { "field" => "status", "operator" => "eq", "value" => "overdue" } },
        { "class" => "lcp-row-bold", "when" => { "field" => "priority", "operator" => "eq", "value" => "high" } }
      ]
      presenter = described_class.from_hash(
        "name" => "test", "model" => "test",
        "index" => { "item_classes" => rules }
      )
      expect(presenter.item_classes.length).to eq(2)
      expect(presenter.item_classes.first["class"]).to eq("lcp-row-danger")
      expect(presenter.item_classes.last["when"]["field"]).to eq("priority")
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
