require "spec_helper"

RSpec.describe LcpRuby::Dsl::PresenterBuilder do
  describe "#to_hash" do
    it "produces a hash with the presenter name" do
      builder = described_class.new(:deal)
      hash = builder.to_hash

      expect(hash["name"]).to eq("deal")
    end

    it "includes model, label, slug, icon when set" do
      builder = described_class.new(:deal)
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
          column :stage, width: "20%", renderer: :badge, sortable: true
        end
      end
      hash = builder.to_hash

      columns = hash["index"]["table_columns"]
      expect(columns.length).to eq(2)
      expect(columns[0]).to eq({
        "field" => "title", "width" => "30%", "link_to" => "show", "sortable" => true
      })
      expect(columns[1]).to eq({
        "field" => "stage", "width" => "20%", "renderer" => "badge", "sortable" => true
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

      expect(hash["index"]["table_columns"]).to eq([ { "field" => "title" } ])
    end

    it "produces row_click" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :deal
        index do
          row_click :show
        end
      end
      hash = builder.to_hash

      expect(hash["index"]["row_click"]).to eq("show")
    end

    it "produces empty_message" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :deal
        index do
          empty_message "No deals yet."
        end
      end
      hash = builder.to_hash

      expect(hash["index"]["empty_message"]).to eq("No deals yet.")
    end

    it "produces includes list" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :deal
        index do
          includes :company, :contact
          column :title
        end
      end
      hash = builder.to_hash

      expect(hash["index"]["includes"]).to eq(%w[company contact])
    end

    it "produces eager_load list" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :deal
        index do
          eager_load :company
          column :title
        end
      end
      hash = builder.to_hash

      expect(hash["index"]["eager_load"]).to eq(%w[company])
    end

    it "handles hash paths in includes" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :deal
        index do
          includes({ company: :industry })
          column :title
        end
      end
      hash = builder.to_hash

      expect(hash["index"]["includes"]).to eq([ { "company" => "industry" } ])
    end

    it "omits includes/eager_load when not set" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :deal
        index do
          column :title
        end
      end
      hash = builder.to_hash

      expect(hash["index"]).not_to have_key("includes")
      expect(hash["index"]).not_to have_key("eager_load")
    end

    it "produces actions_position" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :deal
        index do
          actions_position :dropdown
        end
      end
      hash = builder.to_hash

      expect(hash["index"]["actions_position"]).to eq("dropdown")
    end

    it "produces column with options, hidden_on, pinned, and summary" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :deal
        index do
          column :stage, renderer: :badge, options: { color_map: { open: "blue" } }
          column :value, summary: :sum, hidden_on: :mobile, pinned: :left
        end
      end
      hash = builder.to_hash

      columns = hash["index"]["table_columns"]
      expect(columns[0]["options"]).to eq({ "color_map" => { "open" => "blue" } })
      expect(columns[1]["summary"]).to eq("sum")
      expect(columns[1]["hidden_on"]).to eq("mobile")
      expect(columns[1]["pinned"]).to eq("left")
    end
  end

  describe "show block" do
    it "produces show hash with layout sections" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :deal
        show do
          section "Deal Information", columns: 2 do
            field :title, renderer: :heading
            field :stage, renderer: :badge
          end
        end
      end
      hash = builder.to_hash

      layout = hash["show"]["layout"]
      expect(layout.length).to eq(1)
      expect(layout[0]["section"]).to eq("Deal Information")
      expect(layout[0]["columns"]).to eq(2)
      expect(layout[0]["fields"]).to eq([
        { "field" => "title", "renderer" => "heading" },
        { "field" => "stage", "renderer" => "badge" }
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
            field :name, renderer: :heading
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

    it "supports enhanced association_list with display_template, link, sort, limit, empty_message, scope" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :company
        show do
          association_list "Contacts", association: :contacts,
            display_template: :default,
            link: true,
            sort: { last_name: :asc },
            limit: 5,
            empty_message: "No contacts yet.",
            scope: :active
        end
      end
      hash = builder.to_hash

      entry = hash["show"]["layout"][0]
      expect(entry["section"]).to eq("Contacts")
      expect(entry["type"]).to eq("association_list")
      expect(entry["association"]).to eq("contacts")
      expect(entry["display_template"]).to eq("default")
      expect(entry["link"]).to eq(true)
      expect(entry["sort"]).to eq({ "last_name" => "asc" })
      expect(entry["limit"]).to eq(5)
      expect(entry["empty_message"]).to eq("No contacts yet.")
      expect(entry["scope"]).to eq("active")
    end

    it "omits optional association_list keys when not provided" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :company
        show do
          association_list "Contacts", association: :contacts
        end
      end
      hash = builder.to_hash

      entry = hash["show"]["layout"][0]
      expect(entry).not_to have_key("display_template")
      expect(entry).not_to have_key("link")
      expect(entry).not_to have_key("sort")
      expect(entry).not_to have_key("limit")
      expect(entry).not_to have_key("empty_message")
      expect(entry).not_to have_key("scope")
    end

    it "supports multiple sections" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :project
        show do
          section "Overview", columns: 2 do
            field :title, renderer: :heading
            field :status, renderer: :badge
          end
          section "Details" do
            field :description, renderer: :rich_text
            field :budget, renderer: :currency
          end
        end
      end
      hash = builder.to_hash

      layout = hash["show"]["layout"]
      expect(layout.length).to eq(2)
      expect(layout[0]["section"]).to eq("Overview")
      expect(layout[1]["section"]).to eq("Details")
    end

    it "supports responsive option on sections" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :deal
        show do
          section "Info", columns: 3, responsive: { mobile: { columns: 1 }, tablet: { columns: 2 } } do
            field :title, renderer: :heading
          end
        end
      end
      hash = builder.to_hash

      section = hash["show"]["layout"][0]
      expect(section["responsive"]).to eq({
        "mobile" => { "columns" => 1 },
        "tablet" => { "columns" => 2 }
      })
    end

    it "produces includes and eager_load in show" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :company
        show do
          includes :contacts, :deals
          eager_load :industry
          section "Details" do
            field :name
          end
        end
      end
      hash = builder.to_hash

      expect(hash["show"]["includes"]).to eq(%w[contacts deals])
      expect(hash["show"]["eager_load"]).to eq(%w[industry])
    end

    it "supports col_span, hidden_on, and options on fields" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :deal
        show do
          section "Info", columns: 2 do
            field :title, renderer: :heading, col_span: 2
            field :phone, renderer: :phone_link, hidden_on: :mobile
            field :value, renderer: :currency, options: { currency: "$", precision: 2 }
          end
        end
      end
      hash = builder.to_hash

      fields = hash["show"]["layout"][0]["fields"]
      expect(fields[0]["col_span"]).to eq(2)
      expect(fields[1]["hidden_on"]).to eq("mobile")
      expect(fields[2]["options"]).to eq({ "currency" => "$", "precision" => 2 })
    end

    it "supports visible_when on section" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :deal
        show do
          section "Metrics",
            visible_when: { field: :stage, operator: :not_eq, value: "lead" } do
            field :priority
          end
        end
      end
      hash = builder.to_hash

      section = hash["show"]["layout"][0]
      expect(section["visible_when"]).to eq({
        "field" => "stage", "operator" => "not_eq", "value" => "lead"
      })
    end

    it "supports disable_when on section" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :deal
        show do
          section "Notes",
            disable_when: { field: :stage, operator: :eq, value: "archived" } do
            field :notes
          end
        end
      end
      hash = builder.to_hash

      section = hash["show"]["layout"][0]
      expect(section["disable_when"]).to eq({
        "field" => "stage", "operator" => "eq", "value" => "archived"
      })
    end

    it "supports visible_when on association_list" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :company
        show do
          association_list "Contacts", association: :contacts,
            visible_when: { field: :status, operator: :eq, value: "active" }
        end
      end
      hash = builder.to_hash

      section = hash["show"]["layout"][0]
      expect(section["visible_when"]).to eq({
        "field" => "status", "operator" => "eq", "value" => "active"
      })
    end

    it "stringifies symbol values in visible_when" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :deal
        show do
          section "Info",
            visible_when: { field: :stage, operator: :not_eq, value: :lead } do
            field :title
          end
        end
      end
      hash = builder.to_hash

      section = hash["show"]["layout"][0]
      expect(section["visible_when"]["field"]).to eq("stage")
      expect(section["visible_when"]["operator"]).to eq("not_eq")
      expect(section["visible_when"]["value"]).to eq("lead")
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

    it "produces includes and eager_load in form" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :todo_list
        form do
          includes :todo_items
          section "Items" do
            field :title
          end
        end
      end
      hash = builder.to_hash

      expect(hash["form"]["includes"]).to eq(%w[todo_items])
      expect(hash["form"]).not_to have_key("eager_load")
    end

    it "supports layout option" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :deal
        form do
          layout :tabs
          section "Tab 1" do
            field :title
          end
        end
      end
      hash = builder.to_hash

      expect(hash["form"]["layout"]).to eq("tabs")
    end

    it "supports collapsible and collapsed options" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :deal
        form do
          section "Notes", collapsible: true, collapsed: true do
            field :notes, input_type: :textarea
          end
        end
      end
      hash = builder.to_hash

      section = hash["form"]["sections"][0]
      expect(section["collapsible"]).to eq(true)
      expect(section["collapsed"]).to eq(true)
    end

    it "omits collapsible/collapsed when false" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :deal
        form do
          section "Normal" do
            field :title
          end
        end
      end
      hash = builder.to_hash

      section = hash["form"]["sections"][0]
      expect(section).not_to have_key("collapsible")
      expect(section).not_to have_key("collapsed")
    end

    it "supports responsive on form sections" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :deal
        form do
          section "Info", columns: 2, responsive: { mobile: { columns: 1 } } do
            field :title
          end
        end
      end
      hash = builder.to_hash

      expect(hash["form"]["sections"][0]["responsive"]).to eq({
        "mobile" => { "columns" => 1 }
      })
    end

    it "supports nested_fields" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :order
        form do
          nested_fields "Line Items", association: :line_items,
            allow_add: true, allow_remove: true,
            min: 1, max: 20,
            add_label: "Add Item",
            empty_message: "No items.",
            columns: 3 do
              field :product_name
              field :quantity, input_type: :number
          end
        end
      end
      hash = builder.to_hash

      section = hash["form"]["sections"][0]
      expect(section["type"]).to eq("nested_fields")
      expect(section["title"]).to eq("Line Items")
      expect(section["association"]).to eq("line_items")
      expect(section["allow_add"]).to eq(true)
      expect(section["allow_remove"]).to eq(true)
      expect(section["min"]).to eq(1)
      expect(section["max"]).to eq(20)
      expect(section["add_label"]).to eq("Add Item")
      expect(section["empty_message"]).to eq("No items.")
      expect(section["columns"]).to eq(3)
      expect(section["fields"].length).to eq(2)
      expect(section["fields"][0]["field"]).to eq("product_name")
      expect(section["fields"][1]["input_type"]).to eq("number")
    end

    it "supports sortable: true on nested_fields" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :order
        form do
          nested_fields "Items", association: :items, sortable: true do
            field :name
          end
        end
      end
      hash = builder.to_hash

      section = hash["form"]["sections"][0]
      expect(section["sortable"]).to eq(true)
    end

    it "supports sortable: 'sort_order' on nested_fields" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :order
        form do
          nested_fields "Items", association: :items, sortable: "sort_order" do
            field :name
          end
        end
      end
      hash = builder.to_hash

      section = hash["form"]["sections"][0]
      expect(section["sortable"]).to eq("sort_order")
    end

    it "omits sortable when false (default)" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :order
        form do
          nested_fields "Items", association: :items do
            field :name
          end
        end
      end
      hash = builder.to_hash

      section = hash["form"]["sections"][0]
      expect(section).not_to have_key("sortable")
    end

    it "supports nested_fields with defaults" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :order
        form do
          nested_fields "Items", association: :items do
            field :name
          end
        end
      end
      hash = builder.to_hash

      section = hash["form"]["sections"][0]
      expect(section["allow_add"]).to eq(true)
      expect(section["allow_remove"]).to eq(true)
      expect(section).not_to have_key("min")
      expect(section).not_to have_key("max")
      expect(section).not_to have_key("add_label")
    end

    it "supports divider pseudo-field" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :contact
        form do
          section "Info", columns: 2 do
            field :first_name
            field :last_name
            divider label: "Contact"
            field :email
            field :phone
            divider
            field :notes
          end
        end
      end
      hash = builder.to_hash

      fields = hash["form"]["sections"][0]["fields"]
      expect(fields.length).to eq(7)
      expect(fields[2]).to eq({ "type" => "divider", "label" => "Contact" })
      expect(fields[5]).to eq({ "type" => "divider" })
    end

    it "supports col_span, hint, readonly, suffix, hidden_on on form fields" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :deal
        form do
          section "Details" do
            field :title, col_span: 2, hint: "Help text"
            field :code, readonly: true
            field :weight, suffix: "kg", hidden_on: :mobile
          end
        end
      end
      hash = builder.to_hash

      fields = hash["form"]["sections"][0]["fields"]
      expect(fields[0]["col_span"]).to eq(2)
      expect(fields[0]["hint"]).to eq("Help text")
      expect(fields[1]["readonly"]).to eq(true)
      expect(fields[2]["suffix"]).to eq("kg")
      expect(fields[2]["hidden_on"]).to eq("mobile")
    end

    it "supports visible_when as string on form fields" do
      builder = described_class.new(:test)
      builder.instance_eval do
        model :deal
        form do
          section "Details" do
            field :discount_reason, visible_when: "discounted?"
          end
        end
      end
      hash = builder.to_hash

      field = hash["form"]["sections"][0]["fields"][0]
      expect(field["visible_when"]).to eq("discounted?")
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
      expect(search["searchable_fields"]).to eq([ "title" ])
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
          visible_when: { field: :stage, operator: :not_in, value: [ :closed_won, :closed_lost ] }
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

  describe "#to_hash_with_parent" do
    let(:parent_hash) do
      {
        "name" => "deal",
        "model" => "deal",
        "label" => "Deals",
        "slug" => "deals",
        "icon" => "dollar-sign",
        "index" => {
          "default_view" => "table",
          "per_page" => 25,
          "table_columns" => [ { "field" => "title" } ]
        },
        "show" => {
          "layout" => [ { "section" => "Info", "fields" => [ { "field" => "title" } ] } ]
        },
        "form" => {
          "sections" => [ { "title" => "Details", "fields" => [ { "field" => "title" } ] } ]
        },
        "search" => {
          "enabled" => true,
          "searchable_fields" => [ "title" ]
        },
        "actions" => {
          "collection" => [ { "name" => "create", "type" => "built_in" } ],
          "single" => [ { "name" => "show", "type" => "built_in" } ]
        }
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
        "single" => [ { "name" => "show", "type" => "built_in", "icon" => "eye" } ]
      })
    end

    it "inherits show, form, search from parent when child does not define them" do
      builder = described_class.new(:deal_pipeline)
      builder.instance_eval do
        label "Pipeline"
      end

      merged = builder.to_hash_with_parent(parent_hash)

      expect(merged["show"]).to eq(parent_hash["show"])
      expect(merged["form"]).to eq(parent_hash["form"])
      expect(merged["search"]).to eq(parent_hash["search"])
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

  describe "index reorderable" do
    it "includes reorderable in index config" do
      builder = described_class.new(:stages)
      builder.instance_eval do
        model :stage
        index do
          reorderable
          column :title
        end
      end
      hash = builder.to_hash

      expect(hash["index"]["reorderable"]).to eq(true)
    end

    it "omits reorderable when not set" do
      builder = described_class.new(:stages)
      builder.instance_eval do
        model :stage
        index do
          column :title
        end
      end
      hash = builder.to_hash

      expect(hash["index"]).not_to have_key("reorderable")
    end
  end

  describe "full presenter parity with YAML" do
    let(:fixtures_path) { File.expand_path("../../../fixtures/metadata", __dir__) }
    let(:yaml_hash) do
      YAML.safe_load_file(File.join(fixtures_path, "presenters/project.yml"))["presenter"]
    end

    it "produces the same PresenterDefinition as the YAML fixture" do
      dsl_definition = LcpRuby.define_presenter(:project) do
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
          column :status, width: "15%", renderer: :badge, sortable: true
          column :budget, renderer: :currency, sortable: true
          column :due_date, renderer: :relative_date, sortable: true
        end

        show do
          section "Overview", columns: 2 do
            field :title, renderer: :heading
            field :status, renderer: :badge
          end
          section "Details" do
            field :description, renderer: :rich_text
            field :budget, renderer: :currency
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
          visible_when: { field: :status, operator: :not_in, value: [ :archived, :completed ] },
          style: :danger
        action :destroy, type: :built_in, on: :single, icon: "trash", confirm: true, style: :danger
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

      # Options
      expect(dsl_definition.options).to eq(yaml_definition.options)
    end
  end
end
