require "spec_helper"

RSpec.describe LcpRuby::Metadata::ViewGroupDefinition do
  def valid_attrs(overrides = {})
    {
      name: "tasks_group",
      model: "task",
      primary_presenter: "tasks_table",
      navigation_config: { "icon" => "list", "label" => "Tasks" },
      views: [
        { "presenter" => "tasks_table", "label" => "Table View", "icon" => "table" },
        { "presenter" => "tasks_board", "label" => "Board View", "icon" => "board" }
      ]
    }.merge(overrides)
  end

  describe ".from_hash" do
    it "parses all fields correctly" do
      group = described_class.from_hash(
        "name" => "tasks_group",
        "model" => "task",
        "primary" => "tasks_table",
        "navigation" => { "icon" => "list", "label" => "Tasks" },
        "views" => [
          { "presenter" => "tasks_table", "label" => "Table View", "icon" => "table" },
          { "presenter" => "tasks_board", "label" => "Board View", "icon" => "board" }
        ]
      )

      expect(group.name).to eq("tasks_group")
      expect(group.model).to eq("task")
      expect(group.primary_presenter).to eq("tasks_table")
      expect(group.navigation_config).to eq("icon" => "list", "label" => "Tasks")
      expect(group.views).to eq([
        { "presenter" => "tasks_table", "label" => "Table View", "icon" => "table" },
        { "presenter" => "tasks_board", "label" => "Board View", "icon" => "board" }
      ])
    end

    it "unwraps a top-level view_group key" do
      group = described_class.from_hash(
        "view_group" => {
          "name" => "deals_group",
          "model" => "deal",
          "primary" => "deals_list",
          "views" => [
            { "presenter" => "deals_list" }
          ]
        }
      )

      expect(group.name).to eq("deals_group")
      expect(group.model).to eq("deal")
      expect(group.primary_presenter).to eq("deals_list")
    end

    it "handles compact view entries without label or icon" do
      group = described_class.from_hash(
        "name" => "simple_group",
        "model" => "item",
        "primary" => "items_list",
        "views" => [
          { "presenter" => "items_list" },
          { "presenter" => "items_grid" }
        ]
      )

      expect(group.views).to eq([
        { "presenter" => "items_list" },
        { "presenter" => "items_grid" }
      ])
    end

    it "defaults navigation_config to empty hash when not provided" do
      group = described_class.from_hash(
        "name" => "simple_group",
        "model" => "item",
        "primary" => "items_list",
        "views" => [ { "presenter" => "items_list" } ]
      )

      expect(group.navigation_config).to eq({})
    end
  end

  describe "#presenter_names" do
    it "returns all presenter names from views" do
      group = described_class.new(valid_attrs)

      expect(group.presenter_names).to eq(%w[tasks_table tasks_board])
    end
  end

  describe "#primary?" do
    let(:group) { described_class.new(valid_attrs) }

    it "returns true for the primary presenter" do
      expect(group.primary?("tasks_table")).to be true
    end

    it "returns false for a non-primary presenter" do
      expect(group.primary?("tasks_board")).to be false
    end

    it "converts symbol argument to string for comparison" do
      expect(group.primary?(:tasks_table)).to be true
    end
  end

  describe "#view_for" do
    let(:group) { described_class.new(valid_attrs) }

    it "returns the correct view hash for a given presenter name" do
      view = group.view_for("tasks_board")

      expect(view).to eq("presenter" => "tasks_board", "label" => "Board View", "icon" => "board")
    end

    it "returns nil for an unknown presenter" do
      expect(group.view_for("nonexistent")).to be_nil
    end

    it "converts symbol argument to string for lookup" do
      view = group.view_for(:tasks_table)

      expect(view).to eq("presenter" => "tasks_table", "label" => "Table View", "icon" => "table")
    end
  end

  describe "#has_switcher?" do
    it "returns true when there is more than one view" do
      group = described_class.new(valid_attrs)

      expect(group.has_switcher?).to be true
    end

    it "returns false for a single-view group" do
      group = described_class.new(valid_attrs(
        views: [ { "presenter" => "tasks_table" } ]
      ))

      expect(group.has_switcher?).to be false
    end
  end

  describe "validation" do
    it "raises on missing name" do
      expect {
        described_class.new(valid_attrs(name: ""))
      }.to raise_error(LcpRuby::MetadataError, /name is required/)
    end

    it "raises on nil name" do
      expect {
        described_class.new(valid_attrs(name: nil))
      }.to raise_error(LcpRuby::MetadataError, /name is required/)
    end

    it "raises on missing model" do
      expect {
        described_class.new(valid_attrs(model: ""))
      }.to raise_error(LcpRuby::MetadataError, /requires a model reference/)
    end

    it "raises on empty views" do
      expect {
        described_class.new(valid_attrs(views: []))
      }.to raise_error(LcpRuby::MetadataError, /requires at least one view/)
    end

    it "raises on missing primary presenter" do
      expect {
        described_class.new(valid_attrs(primary_presenter: ""))
      }.to raise_error(LcpRuby::MetadataError, /requires a primary presenter/)
    end

    it "raises when primary presenter is not in the views list" do
      expect {
        described_class.new(valid_attrs(primary_presenter: "nonexistent"))
      }.to raise_error(
        LcpRuby::MetadataError,
        /primary presenter 'nonexistent' is not in the views list/
      )
    end
  end
end
