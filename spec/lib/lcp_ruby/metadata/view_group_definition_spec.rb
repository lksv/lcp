require "spec_helper"

RSpec.describe LcpRuby::Metadata::ViewGroupDefinition do
  def valid_attrs(overrides = {})
    {
      name: "tasks_group",
      model: "task",
      primary_page: "tasks_table",
      navigation_config: { "icon" => "list", "label" => "Tasks" },
      views: [
        { "page" => "tasks_table", "label" => "Table View", "icon" => "table" },
        { "page" => "tasks_board", "label" => "Board View", "icon" => "board" }
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
          { "page" => "tasks_table", "label" => "Table View", "icon" => "table" },
          { "page" => "tasks_board", "label" => "Board View", "icon" => "board" }
        ]
      )

      expect(group.name).to eq("tasks_group")
      expect(group.model).to eq("task")
      expect(group.primary_page).to eq("tasks_table")
      expect(group.navigation_config).to eq("icon" => "list", "label" => "Tasks")
      expect(group.views).to eq([
        { "page" => "tasks_table", "label" => "Table View", "icon" => "table" },
        { "page" => "tasks_board", "label" => "Board View", "icon" => "board" }
      ])
    end

    it "unwraps a top-level view_group key" do
      group = described_class.from_hash(
        "view_group" => {
          "name" => "deals_group",
          "model" => "deal",
          "primary" => "deals_list",
          "views" => [
            { "page" => "deals_list" }
          ]
        }
      )

      expect(group.name).to eq("deals_group")
      expect(group.model).to eq("deal")
      expect(group.primary_page).to eq("deals_list")
    end

    it "handles compact view entries without label or icon" do
      group = described_class.from_hash(
        "name" => "simple_group",
        "model" => "item",
        "primary" => "items_list",
        "views" => [
          { "page" => "items_list" },
          { "page" => "items_grid" }
        ]
      )

      expect(group.views).to eq([
        { "page" => "items_list" },
        { "page" => "items_grid" }
      ])
    end

    it "defaults navigation_config to empty hash when not provided" do
      group = described_class.from_hash(
        "name" => "simple_group",
        "model" => "item",
        "primary" => "items_list",
        "views" => [ { "page" => "items_list" } ]
      )

      expect(group.navigation_config).to eq({})
    end

    it "parses switcher: false" do
      group = described_class.from_hash(
        "name" => "tasks_group",
        "model" => "task",
        "primary" => "tasks_table",
        "switcher" => false,
        "views" => [
          { "page" => "tasks_table" },
          { "page" => "tasks_board" }
        ]
      )

      expect(group.switcher_config).to eq(false)
    end

    it "parses switcher: [show]" do
      group = described_class.from_hash(
        "name" => "tasks_group",
        "model" => "task",
        "primary" => "tasks_table",
        "switcher" => [ "show" ],
        "views" => [
          { "page" => "tasks_table" },
          { "page" => "tasks_board" }
        ]
      )

      expect(group.switcher_config).to eq([ "show" ])
    end

    it "parses switcher: [form]" do
      group = described_class.from_hash(
        "name" => "tasks_group",
        "model" => "task",
        "primary" => "tasks_table",
        "switcher" => [ "form" ],
        "views" => [
          { "page" => "tasks_table" },
          { "page" => "tasks_board" }
        ]
      )

      expect(group.switcher_config).to eq([ "form" ])
    end

    it "defaults switcher to :auto when key is absent" do
      group = described_class.from_hash(
        "name" => "tasks_group",
        "model" => "task",
        "primary" => "tasks_table",
        "views" => [ { "page" => "tasks_table" } ]
      )

      expect(group.switcher_config).to eq(:auto)
    end
  end

  describe "#page_names" do
    it "returns all page names from views" do
      group = described_class.new(valid_attrs)

      expect(group.page_names).to eq(%w[tasks_table tasks_board])
    end
  end

  describe "#primary_page?" do
    let(:group) { described_class.new(valid_attrs) }

    it "returns true for the primary page" do
      expect(group.primary_page?("tasks_table")).to be true
    end

    it "returns false for a non-primary page" do
      expect(group.primary_page?("tasks_board")).to be false
    end

    it "converts symbol argument to string for comparison" do
      expect(group.primary_page?(:tasks_table)).to be true
    end
  end

  describe "#view_for_page" do
    let(:group) { described_class.new(valid_attrs) }

    it "returns the correct view hash for a given page name" do
      view = group.view_for_page("tasks_board")

      expect(view).to eq("page" => "tasks_board", "label" => "Board View", "icon" => "board")
    end

    it "returns nil for an unknown page" do
      expect(group.view_for_page("nonexistent")).to be_nil
    end

    it "converts symbol argument to string for lookup" do
      view = group.view_for_page(:tasks_table)

      expect(view).to eq("page" => "tasks_table", "label" => "Table View", "icon" => "table")
    end
  end

  describe "#has_switcher?" do
    it "returns true when there is more than one view" do
      group = described_class.new(valid_attrs)

      expect(group.has_switcher?).to be true
    end

    it "returns false for a single-view group" do
      group = described_class.new(valid_attrs(
        views: [ { "page" => "tasks_table" } ]
      ))

      expect(group.has_switcher?).to be false
    end

    it "returns false when switcher is false even with multiple views" do
      group = described_class.new(valid_attrs(switcher_config: false))

      expect(group.has_switcher?).to be false
    end
  end

  describe "#show_switcher?" do
    context "with switcher: false" do
      it "returns false for all contexts" do
        group = described_class.new(valid_attrs(switcher_config: false))

        expect(group.show_switcher?(:index)).to be false
        expect(group.show_switcher?(:show)).to be false
        expect(group.show_switcher?(:form)).to be false
      end
    end

    context "with single view" do
      it "returns false regardless of config" do
        group = described_class.new(valid_attrs(
          views: [ { "page" => "tasks_table" } ]
        ))

        expect(group.show_switcher?(:index)).to be false
        expect(group.show_switcher?(:show)).to be false
        expect(group.show_switcher?(:form)).to be false
      end
    end

    context "with explicit [show]" do
      it "returns true only for show, false for index and form" do
        group = described_class.new(valid_attrs(switcher_config: [ "show" ]))

        expect(group.show_switcher?(:index)).to be false
        expect(group.show_switcher?(:show)).to be true
        expect(group.show_switcher?(:form)).to be false
      end
    end

    context "with explicit [index, show, form]" do
      it "returns true for all three" do
        group = described_class.new(valid_attrs(switcher_config: %w[index show form]))

        expect(group.show_switcher?(:index)).to be true
        expect(group.show_switcher?(:show)).to be true
        expect(group.show_switcher?(:form)).to be true
      end
    end

    context "with auto-detection" do
      let(:presenter_a) do
        instance_double(
          LcpRuby::Metadata::PresenterDefinition,
          index_config: { "table_columns" => [ { "field" => "name" } ] },
          show_config: { "layout" => [ { "section" => "Details" } ] },
          form_config: { "sections" => [ { "title" => "Info" } ] }
        )
      end

      let(:presenter_b_different_index) do
        instance_double(
          LcpRuby::Metadata::PresenterDefinition,
          index_config: { "table_columns" => [ { "field" => "name" }, { "field" => "status" } ] },
          show_config: { "layout" => [ { "section" => "Details" } ] },
          form_config: { "sections" => [ { "title" => "Info" } ] }
        )
      end

      let(:presenter_b_different_form) do
        instance_double(
          LcpRuby::Metadata::PresenterDefinition,
          index_config: { "table_columns" => [ { "field" => "name" } ] },
          show_config: { "layout" => [ { "section" => "Details" } ] },
          form_config: { "sections" => [ { "title" => "Extended Info", "columns" => 2 } ] }
        )
      end

      let(:presenter_b_all_same) do
        instance_double(
          LcpRuby::Metadata::PresenterDefinition,
          index_config: { "table_columns" => [ { "field" => "name" } ] },
          show_config: { "layout" => [ { "section" => "Details" } ] },
          form_config: { "sections" => [ { "title" => "Info" } ] }
        )
      end

      let(:page_a) do
        instance_double(LcpRuby::Metadata::PageDefinition, main_presenter_name: "tasks_table")
      end

      let(:page_b) do
        instance_double(LcpRuby::Metadata::PageDefinition, main_presenter_name: "tasks_board")
      end

      before do
        loader = instance_double("LcpRuby::Metadata::Loader")
        allow(LcpRuby).to receive(:loader).and_return(loader)
        allow(LcpRuby.loader).to receive(:page_definitions).and_return(
          "tasks_table" => page_a,
          "tasks_board" => page_b
        )
      end

      it "returns true for index when index configs differ, false for show and form" do
        allow(LcpRuby.loader).to receive(:presenter_definitions).and_return(
          "tasks_table" => presenter_a,
          "tasks_board" => presenter_b_different_index
        )

        group = described_class.new(valid_attrs)

        expect(group.show_switcher?(:index)).to be true
        expect(group.show_switcher?(:show)).to be false
        expect(group.show_switcher?(:form)).to be false
      end

      it "returns true for form when form configs differ" do
        allow(LcpRuby.loader).to receive(:presenter_definitions).and_return(
          "tasks_table" => presenter_a,
          "tasks_board" => presenter_b_different_form
        )

        group = described_class.new(valid_attrs)

        expect(group.show_switcher?(:form)).to be true
        expect(group.show_switcher?(:index)).to be false
        expect(group.show_switcher?(:show)).to be false
      end

      it "returns false for all contexts when all configs are identical" do
        allow(LcpRuby.loader).to receive(:presenter_definitions).and_return(
          "tasks_table" => presenter_a,
          "tasks_board" => presenter_b_all_same
        )

        group = described_class.new(valid_attrs)

        expect(group.show_switcher?(:index)).to be false
        expect(group.show_switcher?(:show)).to be false
        expect(group.show_switcher?(:form)).to be false
      end

      it "raises ArgumentError for unknown context" do
        allow(LcpRuby.loader).to receive(:presenter_definitions).and_return(
          "tasks_table" => presenter_a,
          "tasks_board" => presenter_b_all_same
        )

        group = described_class.new(valid_attrs)

        expect { group.show_switcher?(:edit) }.to raise_error(
          ArgumentError, /Unknown switcher context 'edit'/
        )
      end
    end
  end

  describe "switcher validation" do
    it "accepts nil (defaults to auto)" do
      group = described_class.new(valid_attrs(switcher_config: nil))

      expect(group.switcher_config).to eq(:auto)
    end

    it "accepts 'auto' string" do
      group = described_class.new(valid_attrs(switcher_config: "auto"))

      expect(group.switcher_config).to eq(:auto)
    end

    it "rejects invalid string values" do
      expect {
        described_class.new(valid_attrs(switcher_config: "always"))
      }.to raise_error(LcpRuby::MetadataError, /switcher must be false, 'auto', or an array/)
    end

    it "rejects invalid context names in array" do
      expect {
        described_class.new(valid_attrs(switcher_config: [ "edit" ]))
      }.to raise_error(LcpRuby::MetadataError, /invalid switcher contexts: edit/)
    end

    it "accepts valid contexts in array" do
      group = described_class.new(valid_attrs(switcher_config: %w[index show form]))

      expect(group.switcher_config).to eq(%w[index show form])
    end
  end

  describe "#navigable?" do
    it "returns true by default" do
      group = described_class.new(valid_attrs)

      expect(group.navigable?).to be true
    end

    it "returns true when navigation_config is a hash" do
      group = described_class.new(valid_attrs(navigation_config: { "menu" => "main" }))

      expect(group.navigable?).to be true
    end

    it "returns true when navigation_config is an empty hash" do
      group = described_class.new(valid_attrs(navigation_config: {}))

      expect(group.navigable?).to be true
    end

    it "returns false when navigation_config is false" do
      group = described_class.new(valid_attrs(navigation_config: false))

      expect(group.navigable?).to be false
      expect(group.navigation_config).to eq(false)
    end
  end

  describe ".from_hash with navigation: false" do
    it "sets navigation_config to false" do
      group = described_class.from_hash(
        "name" => "audit",
        "model" => "audit_log",
        "primary" => "audit_log",
        "navigation" => false,
        "views" => [ { "page" => "audit_log" } ]
      )

      expect(group.navigation_config).to eq(false)
      expect(group.navigable?).to be false
    end

    it "sets navigation_config to hash when provided" do
      group = described_class.from_hash(
        "name" => "tasks",
        "model" => "task",
        "primary" => "task_list",
        "navigation" => { "menu" => "main", "position" => 1 },
        "views" => [ { "page" => "task_list" } ]
      )

      expect(group.navigation_config).to eq("menu" => "main", "position" => 1)
      expect(group.navigable?).to be true
    end
  end

  describe "#breadcrumb_config" do
    it "defaults to nil when not provided" do
      group = described_class.new(valid_attrs)

      expect(group.breadcrumb_config).to be_nil
    end

    it "accepts false to disable breadcrumbs" do
      group = described_class.new(valid_attrs(breadcrumb_config: false))

      expect(group.breadcrumb_config).to eq(false)
    end

    it "accepts a hash with relation key" do
      group = described_class.new(valid_attrs(breadcrumb_config: { "relation" => "company" }))

      expect(group.breadcrumb_config).to eq("relation" => "company")
    end

    it "stringifies symbol keys in the hash" do
      group = described_class.new(valid_attrs(breadcrumb_config: { relation: "company" }))

      expect(group.breadcrumb_config).to eq("relation" => "company")
    end

    it "raises on invalid breadcrumb value" do
      expect {
        described_class.new(valid_attrs(breadcrumb_config: "invalid"))
      }.to raise_error(LcpRuby::MetadataError, /breadcrumb must be false or a Hash/)
    end
  end

  describe "#breadcrumb_enabled?" do
    it "returns true by default (no breadcrumb config)" do
      group = described_class.new(valid_attrs)

      expect(group.breadcrumb_enabled?).to be true
    end

    it "returns false when breadcrumb is explicitly false" do
      group = described_class.new(valid_attrs(breadcrumb_config: false))

      expect(group.breadcrumb_enabled?).to be false
    end

    it "returns true when breadcrumb has a relation" do
      group = described_class.new(valid_attrs(breadcrumb_config: { "relation" => "company" }))

      expect(group.breadcrumb_enabled?).to be true
    end
  end

  describe "#breadcrumb_relation" do
    it "returns nil when no breadcrumb config" do
      group = described_class.new(valid_attrs)

      expect(group.breadcrumb_relation).to be_nil
    end

    it "returns nil when breadcrumb is false" do
      group = described_class.new(valid_attrs(breadcrumb_config: false))

      expect(group.breadcrumb_relation).to be_nil
    end

    it "returns the relation name from breadcrumb config" do
      group = described_class.new(valid_attrs(breadcrumb_config: { "relation" => "company" }))

      expect(group.breadcrumb_relation).to eq("company")
    end
  end

  describe ".from_hash with breadcrumb" do
    it "parses breadcrumb: false" do
      group = described_class.from_hash(
        "name" => "tasks_group",
        "model" => "task",
        "primary" => "tasks_table",
        "breadcrumb" => false,
        "views" => [ { "page" => "tasks_table" } ]
      )

      expect(group.breadcrumb_config).to eq(false)
      expect(group.breadcrumb_enabled?).to be false
    end

    it "parses breadcrumb with relation" do
      group = described_class.from_hash(
        "name" => "deals_group",
        "model" => "deal",
        "primary" => "deals_list",
        "breadcrumb" => { "relation" => "company" },
        "views" => [ { "page" => "deals_list" } ]
      )

      expect(group.breadcrumb_config).to eq("relation" => "company")
      expect(group.breadcrumb_relation).to eq("company")
    end

    it "defaults breadcrumb to nil when key is absent" do
      group = described_class.from_hash(
        "name" => "simple_group",
        "model" => "item",
        "primary" => "items_list",
        "views" => [ { "page" => "items_list" } ]
      )

      expect(group.breadcrumb_config).to be_nil
      expect(group.breadcrumb_enabled?).to be true
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

    it "allows nil model for standalone pages" do
      group = described_class.new(valid_attrs(model: ""))

      expect(group.model).to eq("")
    end

    it "raises on empty views" do
      expect {
        described_class.new(valid_attrs(views: []))
      }.to raise_error(LcpRuby::MetadataError, /requires at least one view/)
    end

    it "raises on missing primary page" do
      expect {
        described_class.new(valid_attrs(primary_page: ""))
      }.to raise_error(LcpRuby::MetadataError, /requires a primary page/)
    end

    it "raises when primary page is not in the views list" do
      expect {
        described_class.new(valid_attrs(primary_page: "nonexistent"))
      }.to raise_error(
        LcpRuby::MetadataError,
        /primary page 'nonexistent' is not in the views list/
      )
    end
  end
end
