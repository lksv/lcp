require "spec_helper"

RSpec.describe LcpRuby::Dsl::ViewGroupBuilder do
  describe "#to_hash" do
    it "produces a hash with the view group name" do
      builder = described_class.new(:crm_contacts)
      hash = builder.to_hash

      expect(hash).to have_key("view_group")
      expect(hash["view_group"]["name"]).to eq("crm_contacts")
    end

    it "includes model, primary, and navigation when set" do
      builder = described_class.new(:crm_contacts)
      builder.instance_eval do
        model :contact
        primary :contacts_table
        navigation menu: :main, position: 2
      end
      hash = builder.to_hash

      vg = hash["view_group"]
      expect(vg["model"]).to eq("contact")
      expect(vg["primary"]).to eq("contacts_table")
      expect(vg["navigation"]).to eq({ "menu" => "main", "position" => 2 })
    end

    it "includes views array with presenter, label, and icon" do
      builder = described_class.new(:crm_contacts)
      builder.instance_eval do
        view :contacts_table, label: "Table View", icon: :table
        view :contacts_board, label: "Board View", icon: :board
      end
      hash = builder.to_hash

      views = hash["view_group"]["views"]
      expect(views.length).to eq(2)
      expect(views[0]).to eq({
        "presenter" => "contacts_table",
        "label" => "Table View",
        "icon" => "table"
      })
      expect(views[1]).to eq({
        "presenter" => "contacts_board",
        "label" => "Board View",
        "icon" => "board"
      })
    end

    it "omits navigation when not set" do
      builder = described_class.new(:crm_contacts)
      builder.instance_eval do
        model :contact
        primary :contacts_table
        view :contacts_table, label: "Table"
      end
      hash = builder.to_hash

      expect(hash["view_group"]).not_to have_key("navigation")
    end

    it "supports view without icon" do
      builder = described_class.new(:crm_contacts)
      builder.instance_eval do
        view :contacts_table, label: "Table View"
      end
      hash = builder.to_hash

      view = hash["view_group"]["views"].first
      expect(view["presenter"]).to eq("contacts_table")
      expect(view["label"]).to eq("Table View")
      expect(view).not_to have_key("icon")
    end

    it "omits views key when no views defined" do
      builder = described_class.new(:crm_contacts)
      hash = builder.to_hash

      expect(hash["view_group"]).not_to have_key("views")
    end

    it "omits model when not set" do
      builder = described_class.new(:crm_contacts)
      hash = builder.to_hash

      expect(hash["view_group"]).not_to have_key("model")
    end

    it "omits primary when not set" do
      builder = described_class.new(:crm_contacts)
      hash = builder.to_hash

      expect(hash["view_group"]).not_to have_key("primary")
    end

    it "supports navigation without position" do
      builder = described_class.new(:crm_contacts)
      builder.instance_eval do
        navigation menu: :sidebar
      end
      hash = builder.to_hash

      expect(hash["view_group"]["navigation"]).to eq({ "menu" => "sidebar" })
    end

    it "converts symbol name to string" do
      builder = described_class.new(:my_group)
      hash = builder.to_hash

      expect(hash["view_group"]["name"]).to eq("my_group")
    end

    it "accepts string name as-is" do
      builder = described_class.new("my_group")
      hash = builder.to_hash

      expect(hash["view_group"]["name"]).to eq("my_group")
    end

    it "supports view with only presenter name (no label, no icon)" do
      builder = described_class.new(:crm_contacts)
      builder.instance_eval do
        view :contacts_table
      end
      hash = builder.to_hash

      view = hash["view_group"]["views"].first
      expect(view).to eq({ "presenter" => "contacts_table" })
      expect(view).not_to have_key("label")
      expect(view).not_to have_key("icon")
    end

    it "accumulates multiple views in order" do
      builder = described_class.new(:crm_contacts)
      builder.instance_eval do
        view :view_a, label: "A"
        view :view_b, label: "B"
        view :view_c, label: "C"
      end
      hash = builder.to_hash

      views = hash["view_group"]["views"]
      expect(views.length).to eq(3)
      expect(views.map { |v| v["presenter"] }).to eq(%w[view_a view_b view_c])
    end
  end

  describe "full round-trip: DSL -> to_hash -> ViewGroupDefinition" do
    it "produces a valid ViewGroupDefinition from builder hash" do
      builder = described_class.new(:crm_contacts)
      builder.instance_eval do
        model :contact
        primary :contacts_table
        navigation menu: :main, position: 1
        view :contacts_table, label: "Table View", icon: :table
        view :contacts_board, label: "Board View", icon: :board
      end

      definition = LcpRuby::Metadata::ViewGroupDefinition.from_hash(builder.to_hash)

      expect(definition.name).to eq("crm_contacts")
      expect(definition.model).to eq("contact")
      expect(definition.primary_presenter).to eq("contacts_table")
      expect(definition.navigation_config).to eq({ "menu" => "main", "position" => 1 })
      expect(definition.views.length).to eq(2)
      expect(definition.presenter_names).to eq(%w[contacts_table contacts_board])
      expect(definition.primary?(:contacts_table)).to be true
      expect(definition.primary?(:contacts_board)).to be false
      expect(definition.has_switcher?).to be true
    end

    it "produces a valid definition with a single view" do
      builder = described_class.new(:simple_group)
      builder.instance_eval do
        model :task
        primary :tasks_list
        view :tasks_list, label: "Tasks"
      end

      definition = LcpRuby::Metadata::ViewGroupDefinition.from_hash(builder.to_hash)

      expect(definition.name).to eq("simple_group")
      expect(definition.model).to eq("task")
      expect(definition.primary_presenter).to eq("tasks_list")
      expect(definition.views.length).to eq(1)
      expect(definition.has_switcher?).to be false
    end

    it "preserves view details through the round-trip" do
      builder = described_class.new(:detailed)
      builder.instance_eval do
        model :deal
        primary :deals_table
        view :deals_table, label: "Table", icon: :list
        view :deals_kanban, label: "Kanban", icon: :columns
      end

      definition = LcpRuby::Metadata::ViewGroupDefinition.from_hash(builder.to_hash)

      table_view = definition.view_for(:deals_table)
      expect(table_view["presenter"]).to eq("deals_table")
      expect(table_view["label"]).to eq("Table")
      expect(table_view["icon"]).to eq("list")

      kanban_view = definition.view_for(:deals_kanban)
      expect(kanban_view["presenter"]).to eq("deals_kanban")
      expect(kanban_view["label"]).to eq("Kanban")
      expect(kanban_view["icon"]).to eq("columns")
    end
  end
end
