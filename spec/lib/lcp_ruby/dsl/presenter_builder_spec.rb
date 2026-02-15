require "spec_helper"

RSpec.describe LcpRuby::Dsl::PresenterBuilder do
  describe "#to_hash" do
    it "produces a hash with the presenter name" do
      builder = described_class.new(:deal_admin)
      hash = builder.to_hash

      expect(hash["name"]).to eq("deal_admin")
    end

    it "includes model, label, slug, icon when set" do
      builder = described_class.new(:deal_admin)
      builder.instance_eval do
        model :deal
        label "Deals"
        slug "deals"
        icon "dollar-sign"
      end
      hash = builder.to_hash

      expect(hash["model"]).to eq("deal")
      expect(hash["label"]).to eq("Deals")
      expect(hash["slug"]).to eq("deals")
      expect(hash["icon"]).to eq("dollar-sign")
    end

    it "omits optional keys when not set" do
      builder = described_class.new(:minimal)
      hash = builder.to_hash

      expect(hash).not_to have_key("model")
      expect(hash).not_to have_key("label")
      expect(hash).not_to have_key("slug")
      expect(hash).not_to have_key("icon")
      expect(hash).not_to have_key("index")
      expect(hash).not_to have_key("show")
      expect(hash).not_to have_key("form")
      expect(hash).not_to have_key("search")
      expect(hash).not_to have_key("actions")
      expect(hash).not_to have_key("navigation")
    end

    it "includes read_only at top level" do
      builder = described_class.new(:readonly)
      builder.instance_eval do
        model :deal
        read_only true
      end
      hash = builder.to_hash

      expect(hash["read_only"]).to eq(true)
    end

    it "includes embeddable at top level" do
      builder = described_class.new(:embeddable)
      builder.instance_eval do
        model :deal
        embeddable true
      end
      hash = builder.to_hash

      expect(hash["embeddable"]).to eq(true)
    end

    it "supports read_only without argument (defaults to true)" do
      builder = described_class.new(:readonly)
      builder.instance_eval do
        model :deal
        read_only
      end
      hash = builder.to_hash

      expect(hash["read_only"]).to eq(true)
    end
  end

  describe "index block" do
    it "produces index hash with default_view and per_page" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :deal
        index do
          default_view :table
          per_page 25
        end
      end
      hash = builder.to_hash

      expect(hash["index"]["default_view"]).to eq("table")
      expect(hash["index"]["per_page"]).to eq(25)
    end

    it "produces index hash with default_sort" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :deal
        index do
          default_sort :created_at, :desc
        end
      end
      hash = builder.to_hash

      expect(hash["index"]["default_sort"]).to eq({
        "field" => "created_at", "direction" => "desc"
      })
    end

    it "produces index hash with views_available" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :deal
        index do
          default_view :table
          views_available :table, :tiles
        end
      end
      hash = builder.to_hash

      expect(hash["index"]["views_available"]).to eq(%w[table tiles])
    end

    it "produces table_columns array" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :deal
        index do
          column :title, width: "30%", link_to: :show, sortable: true
          column :stage, width: "20%", display: :badge, sortable: true
        end
      end
      hash = builder.to_hash

      columns = hash["index"]["table_columns"]
      expect(columns.length).to eq(2)
      expect(columns[0]).to eq({
        "field" => "title", "width" => "30%", "link_to" => "show", "sortable" => true
      })
      expect(columns[1]).to eq({
        "field" => "stage", "width" => "20%", "display" => "badge", "sortable" => true
      })
    end

    it "produces column with minimal options" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :deal
        index do
          column :title
        end
      end
      hash = builder.to_hash

      expect(hash["index"]["table_columns"]).to eq([{ "field" => "title" }])
    end
  end

  describe "show block" do
    it "produces show hash with layout sections" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :deal
        show do
          section "Deal Information", columns: 2 do
            field :title, display: :heading
            field :stage, display: :badge
          end
        end
      end
      hash = builder.to_hash

      layout = hash["show"]["layout"]
      expect(layout.length).to eq(1)
      expect(layout[0]["section"]).to eq("Deal Information")
      expect(layout[0]["columns"]).to eq(2)
      expect(layout[0]["fields"]).to eq([
        { "field" => "title", "display" => "heading" },
        { "field" => "stage", "display" => "badge" }
      ])
    end

    it "defaults section columns to 1" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :deal
        show do
          section "Details" do
            field :title
          end
        end
      end
      hash = builder.to_hash

      expect(hash["show"]["layout"][0]["columns"]).to eq(1)
    end

    it "supports association_list" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :company
        show do
          section "Details" do
            field :name, display: :heading
          end
          association_list "Contacts", association: :contacts
        end
      end
      hash = builder.to_hash

      layout = hash["show"]["layout"]
      expect(layout.length).to eq(2)
      expect(layout[1]).to eq({
        "section" => "Contacts",
        "type" => "association_list",
        "association" => "contacts"
      })
    end

    it "supports multiple sections" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :project
        show do
          section "Overview", columns: 2 do
            field :title, display: :heading
            field :status, display: :badge
          end
          section "Details" do
            field :description, display: :rich_text
            field :budget, display: :currency
          end
        end
      end
      hash = builder.to_hash

      layout = hash["show"]["layout"]
      expect(layout.length).to eq(2)
      expect(layout[0]["section"]).to eq("Overview")
      expect(layout[1]["section"]).to eq("Details")
    end
  end

  describe "form block" do
    it "produces form hash with sections" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :deal
        form do
          section "Deal Details", columns: 2 do
            field :title, placeholder: "Deal title...", autofocus: true
            field :stage, input_type: :select
            field :value, input_type: :number
          end
        end
      end
      hash = builder.to_hash

      sections = hash["form"]["sections"]
      expect(sections.length).to eq(1)
      expect(sections[0]["title"]).to eq("Deal Details")
      expect(sections[0]["columns"]).to eq(2)
      expect(sections[0]["fields"]).to eq([
        { "field" => "title", "placeholder" => "Deal title...", "autofocus" => true },
        { "field" => "stage", "input_type" => "select" },
        { "field" => "value", "input_type" => "number" }
      ])
    end

    it "supports association_select input_type" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :deal
        form do
          section "Relations" do
            field :company_id, input_type: :association_select
          end
        end
      end
      hash = builder.to_hash

      field = hash["form"]["sections"][0]["fields"][0]
      expect(field["input_type"]).to eq("association_select")
    end

    it "supports multiple form sections" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :project
        form do
          section "Basic Info", columns: 2 do
            field :title
            field :status, input_type: :select
          end
          section "Details" do
            field :description, input_type: :text
          end
          section "Timeline", columns: 3 do
            field :budget, input_type: :number, prefix: "$"
            field :start_date, input_type: :date_picker
            field :due_date, input_type: :date_picker
          end
        end
      end
      hash = builder.to_hash

      sections = hash["form"]["sections"]
      expect(sections.length).to eq(3)
      expect(sections[0]["columns"]).to eq(2)
      expect(sections[1]["columns"]).to eq(1)
      expect(sections[2]["columns"]).to eq(3)
    end
  end

  describe "search block" do
    it "produces search hash with full config" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :deal
        search do
          searchable_fields :title
          placeholder "Search deals..."
          filter :all, label: "All", default: true
          filter :open, label: "Open", scope: :open_deals
        end
      end
      hash = builder.to_hash

      search = hash["search"]
      expect(search["enabled"]).to eq(true)
      expect(search["searchable_fields"]).to eq(["title"])
      expect(search["placeholder"]).to eq("Search deals...")
      expect(search["predefined_filters"]).to eq([
        { "name" => "all", "label" => "All", "default" => true },
        { "name" => "open", "label" => "Open", "scope" => "open_deals" }
      ])
    end

    it "supports multiple searchable fields" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :contact
        search do
          searchable_fields :first_name, :last_name, :email
        end
      end
      hash = builder.to_hash

      expect(hash["search"]["searchable_fields"]).to eq(%w[first_name last_name email])
    end

    it "supports disabled search via keyword argument" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :deal
        search enabled: false
      end
      hash = builder.to_hash

      expect(hash["search"]).to eq({ "enabled" => false })
    end

    it "supports explicit enabled: false inside block" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :deal
        search do
          enabled false
        end
      end
      hash = builder.to_hash

      expect(hash["search"]["enabled"]).to eq(false)
    end

    it "omits predefined_filters when none defined" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :deal
        search do
          searchable_fields :title
        end
      end
      hash = builder.to_hash

      expect(hash["search"]).not_to have_key("predefined_filters")
    end
  end

  describe "actions" do
    it "groups actions by collection and single" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :deal
        action :create, type: :built_in, on: :collection, label: "New Deal", icon: "plus"
        action :show, type: :built_in, on: :single, icon: "eye"
        action :edit, type: :built_in, on: :single, icon: "pencil"
      end
      hash = builder.to_hash

      expect(hash["actions"]["collection"]).to eq([
        { "name" => "create", "type" => "built_in", "label" => "New Deal", "icon" => "plus" }
      ])
      expect(hash["actions"]["single"].length).to eq(2)
      expect(hash["actions"]["single"][0]["name"]).to eq("show")
      expect(hash["actions"]["single"][1]["name"]).to eq("edit")
    end

    it "supports confirm and confirm_message" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :deal
        action :destroy, type: :built_in, on: :single, icon: "trash",
          confirm: true, style: :danger
      end
      hash = builder.to_hash

      action = hash["actions"]["single"][0]
      expect(action["confirm"]).to eq(true)
      expect(action["style"]).to eq("danger")
    end

    it "supports custom actions with visible_when" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :deal
        action :close_won, type: :custom, on: :single,
          label: "Close as Won", icon: "check-circle",
          confirm: true, confirm_message: "Mark this deal as won?",
          visible_when: { field: :stage, operator: :not_in, value: [:closed_won, :closed_lost] }
      end
      hash = builder.to_hash

      action = hash["actions"]["single"][0]
      expect(action["name"]).to eq("close_won")
      expect(action["type"]).to eq("custom")
      expect(action["label"]).to eq("Close as Won")
      expect(action["confirm_message"]).to eq("Mark this deal as won?")
      expect(action["visible_when"]).to eq({
        "field" => "stage",
        "operator" => "not_in",
        "value" => %w[closed_won closed_lost]
      })
    end

    it "omits actions key when no actions defined" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :deal
      end
      hash = builder.to_hash

      expect(hash).not_to have_key("actions")
    end
  end

  describe "navigation" do
    it "produces navigation hash with menu and position" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :deal
        navigation menu: :main, position: 3
      end
      hash = builder.to_hash

      expect(hash["navigation"]).to eq({ "menu" => "main", "position" => 3 })
    end

    it "supports navigation without position" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :deal
        navigation menu: :public
      end
      hash = builder.to_hash

      expect(hash["navigation"]).to eq({ "menu" => "public" })
    end
  end

  describe "#to_hash_with_parent" do
    let(:parent_hash) do
      {
        "name" => "deal_admin",
        "model" => "deal",
        "label" => "Deals",
        "slug" => "deals",
        "icon" => "dollar-sign",
        "index" => {
          "default_view" => "table",
          "per_page" => 25,
          "table_columns" => [{ "field" => "title" }]
        },
        "show" => {
          "layout" => [{ "section" => "Info", "fields" => [{ "field" => "title" }] }]
        },
        "form" => {
          "sections" => [{ "title" => "Details", "fields" => [{ "field" => "title" }] }]
        },
        "search" => {
          "enabled" => true,
          "searchable_fields" => ["title"]
        },
        "actions" => {
          "collection" => [{ "name" => "create", "type" => "built_in" }],
          "single" => [{ "name" => "show", "type" => "built_in" }]
        },
        "navigation" => { "menu" => "main", "position" => 3 }
      }
    end

    it "overrides name, label, slug, icon from child" do
      builder = described_class.new(:deal_pipeline)
      builder.instance_eval do
        label "Deal Pipeline"
        slug "pipeline"
        icon "bar-chart"
      end

      merged = builder.to_hash_with_parent(parent_hash)

      expect(merged["name"]).to eq("deal_pipeline")
      expect(merged["label"]).to eq("Deal Pipeline")
      expect(merged["slug"]).to eq("pipeline")
      expect(merged["icon"]).to eq("bar-chart")
    end

    it "inherits model from parent" do
      builder = described_class.new(:deal_pipeline)
      builder.instance_eval do
        label "Deal Pipeline"
      end

      merged = builder.to_hash_with_parent(parent_hash)

      expect(merged["model"]).to eq("deal")
    end

    it "replaces index entirely when child defines it" do
      builder = described_class.new(:deal_pipeline)
      builder.instance_eval do
        index do
          default_view :table
          per_page 50
          column :title, sortable: true
        end
      end

      merged = builder.to_hash_with_parent(parent_hash)

      expect(merged["index"]["per_page"]).to eq(50)
      expect(merged["index"]["table_columns"].length).to eq(1)
      # Parent's default_sort is gone since child replaces entirely
      expect(merged["index"]).not_to have_key("default_sort")
    end

    it "inherits index from parent when child does not define it" do
      builder = described_class.new(:deal_pipeline)
      builder.instance_eval do
        label "Pipeline"
      end

      merged = builder.to_hash_with_parent(parent_hash)

      expect(merged["index"]).to eq(parent_hash["index"])
    end

    it "replaces actions entirely when child defines them" do
      builder = described_class.new(:deal_pipeline)
      builder.instance_eval do
        action :show, type: :built_in, on: :single, icon: "eye"
      end

      merged = builder.to_hash_with_parent(parent_hash)

      expect(merged["actions"]).to eq({
        "single" => [{ "name" => "show", "type" => "built_in", "icon" => "eye" }]
      })
    end

    it "inherits show, form, search, navigation from parent when child does not define them" do
      builder = described_class.new(:deal_pipeline)
      builder.instance_eval do
        label "Pipeline"
      end

      merged = builder.to_hash_with_parent(parent_hash)

      expect(merged["show"]).to eq(parent_hash["show"])
      expect(merged["form"]).to eq(parent_hash["form"])
      expect(merged["search"]).to eq(parent_hash["search"])
      expect(merged["navigation"]).to eq(parent_hash["navigation"])
    end

    it "adds read_only option from child" do
      builder = described_class.new(:deal_pipeline)
      builder.instance_eval do
        read_only true
      end

      merged = builder.to_hash_with_parent(parent_hash)

      expect(merged["read_only"]).to eq(true)
    end

    it "does not mutate the parent hash" do
      original_parent = parent_hash.dup
      builder = described_class.new(:deal_pipeline)
      builder.instance_eval do
        label "Pipeline"
        read_only true
      end

      builder.to_hash_with_parent(parent_hash)

      expect(parent_hash).to eq(original_parent)
    end
  end

  describe "full presenter parity with YAML" do
    let(:fixtures_path) { File.expand_path("../../../fixtures/metadata", __dir__) }
    let(:yaml_hash) do
      YAML.safe_load_file(File.join(fixtures_path, "presenters/project_admin.yml"))["presenter"]
    end

    it "produces the same PresenterDefinition as the YAML fixture" do
      dsl_definition = LcpRuby.define_presenter(:project_admin) do
        model :project
        label "Project Management"
        slug "projects"
        icon "folder"

        index do
          default_view :table
          views_available :table, :tiles
          default_sort :created_at, :desc
          per_page 25
          column :title, width: "30%", link_to: :show, sortable: true
          column :status, width: "15%", display: :badge, sortable: true
          column :budget, display: :currency, sortable: true
          column :due_date, display: :relative_date, sortable: true
        end

        show do
          section "Overview", columns: 2 do
            field :title, display: :heading
            field :status, display: :badge
          end
          section "Details" do
            field :description, display: :rich_text
            field :budget, display: :currency
          end
        end

        form do
          section "Basic Information", columns: 2 do
            field :title, placeholder: "Enter project title...", autofocus: true
            field :status, input_type: :select
          end
          section "Details" do
            field :description, input_type: :text
          end
          section "Timeline & Budget", columns: 3 do
            field :budget, input_type: :number, prefix: "$"
            field :start_date, input_type: :date_picker
            field :due_date, input_type: :date_picker
          end
        end

        search do
          searchable_fields :title, :description
          placeholder "Search projects..."
          filter :all, label: "All", default: true
          filter :active, label: "Active", scope: :active
        end

        action :create, type: :built_in, on: :collection, label: "New Project", icon: "plus"
        action :show, type: :built_in, on: :single, icon: "eye"
        action :edit, type: :built_in, on: :single, icon: "pencil"
        action :archive, type: :custom, on: :single,
          label: "Archive", icon: "archive",
          confirm: true, confirm_message: "Archive this project?",
          visible_when: { field: :status, operator: :not_in, value: [:archived, :completed] },
          style: :danger
        action :destroy, type: :built_in, on: :single, icon: "trash", confirm: true, style: :danger

        navigation menu: :main, position: 1
      end

      yaml_definition = LcpRuby::Metadata::PresenterDefinition.from_hash(yaml_hash)

      # Top-level attributes
      expect(dsl_definition.name).to eq(yaml_definition.name)
      expect(dsl_definition.model).to eq(yaml_definition.model)
      expect(dsl_definition.label).to eq(yaml_definition.label)
      expect(dsl_definition.slug).to eq(yaml_definition.slug)
      expect(dsl_definition.icon).to eq(yaml_definition.icon)

      # Index
      expect(dsl_definition.index_config).to eq(yaml_definition.index_config)
      expect(dsl_definition.default_view).to eq(yaml_definition.default_view)
      expect(dsl_definition.per_page).to eq(yaml_definition.per_page)
      expect(dsl_definition.table_columns).to eq(yaml_definition.table_columns)

      # Show
      expect(dsl_definition.show_config).to eq(yaml_definition.show_config)

      # Form
      expect(dsl_definition.form_config).to eq(yaml_definition.form_config)

      # Search
      expect(dsl_definition.search_config).to eq(yaml_definition.search_config)

      # Actions
      expect(dsl_definition.collection_actions).to eq(yaml_definition.collection_actions)
      expect(dsl_definition.single_actions).to eq(yaml_definition.single_actions)

      # Navigation
      expect(dsl_definition.navigation_config).to eq(yaml_definition.navigation_config)

      # Options
      expect(dsl_definition.options).to eq(yaml_definition.options)
    end
  end
end
