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

    it "defaults layout to semantic" do
      page = described_class.new(name: "contacts_page", zones: [ main_zone ])
      expect(page.layout).to eq(:semantic)
      expect(page.grid?).to be false
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

    it "raises when layout is invalid" do
      expect {
        described_class.new(name: "test", zones: [ main_zone ], layout: :invalid)
      }.to raise_error(LcpRuby::MetadataError, /invalid layout/)
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

  describe "#standalone?" do
    it "returns true when model is nil" do
      page = described_class.new(name: "dashboard", zones: [ main_zone ])
      expect(page.standalone?).to be true
    end

    it "returns false when model is present" do
      page = described_class.new(name: "test", model: "contact", zones: [ main_zone ])
      expect(page.standalone?).to be false
    end
  end

  describe "#grid?" do
    it "returns true when layout is grid" do
      page = described_class.new(name: "dashboard", layout: :grid, zones: [ main_zone ])
      expect(page.grid?).to be true
    end

    it "returns false when layout is semantic" do
      page = described_class.new(name: "test", zones: [ main_zone ])
      expect(page.grid?).to be false
    end
  end

  describe "#title" do
    it "returns humanized name by default" do
      page = described_class.new(name: "main_dashboard", zones: [ main_zone ])
      expect(page.title).to eq("Main dashboard")
    end

    it "uses title_key for i18n lookup" do
      page = described_class.new(name: "dashboard", title_key: "lcp_ruby.dashboard.title", zones: [ main_zone ])
      # Falls back to humanized name since key isn't defined in locale
      expect(page.title).to eq("Dashboard")
    end

    it "returns translated title when i18n key exists" do
      I18n.backend.store_translations(:en, { my_dashboard: { title: "My Dashboard" } })
      page = described_class.new(name: "dashboard", title_key: "my_dashboard.title", zones: [ main_zone ])
      expect(page.title).to eq("My Dashboard")
    ensure
      I18n.backend.reload!
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

    it "prefers presenter zones over widget zones for main_zone" do
      widget_zone = LcpRuby::Metadata::ZoneDefinition.new(
        name: "kpi", type: :widget,
        widget: { "type" => "kpi_card", "model" => "order", "aggregate" => "count" },
        area: "main"
      )
      presenter_zone = LcpRuby::Metadata::ZoneDefinition.new(name: "list", presenter: "contacts", area: "sidebar")
      page = described_class.new(name: "test", zones: [ widget_zone, presenter_zone ])
      expect(page.main_zone).to eq(presenter_zone)
    end

    it "falls back to first zone when only widget zones" do
      widget_zone = LcpRuby::Metadata::ZoneDefinition.new(
        name: "kpi", type: :widget,
        widget: { "type" => "kpi_card", "model" => "order", "aggregate" => "count" }
      )
      page = described_class.new(name: "test", zones: [ widget_zone ])
      expect(page.main_zone).to eq(widget_zone)
      expect(page.main_presenter_name).to be_nil
    end
  end

  describe "#main_presenter_name" do
    it "returns the main zone presenter" do
      page = described_class.new(name: "test", zones: [ main_zone ])
      expect(page.main_presenter_name).to eq("contacts")
    end

    it "returns nil when main zone is a widget" do
      widget_zone = LcpRuby::Metadata::ZoneDefinition.new(
        name: "kpi", type: :widget,
        widget: { "type" => "text", "content_key" => "hello" }
      )
      page = described_class.new(name: "test", zones: [ widget_zone ])
      expect(page.main_presenter_name).to be_nil
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

  describe "#semantic?" do
    it "returns true when layout is semantic" do
      page = described_class.new(name: "test", zones: [ main_zone ])
      expect(page.semantic?).to be true
    end

    it "returns false when layout is grid" do
      page = described_class.new(name: "test", layout: :grid, zones: [ main_zone ])
      expect(page.semantic?).to be false
    end
  end

  describe "#composite?" do
    it "returns true for multi-zone, non-auto, non-standalone page" do
      tab_zone = LcpRuby::Metadata::ZoneDefinition.new(name: "tab1", presenter: "tasks", area: "tabs")
      page = described_class.new(name: "detail", model: "employee", zones: [ main_zone, tab_zone ])
      expect(page.composite?).to be true
    end

    it "returns false for auto-generated page" do
      tab_zone = LcpRuby::Metadata::ZoneDefinition.new(name: "tab1", presenter: "tasks", area: "tabs")
      page = described_class.new(name: "detail", model: "employee", zones: [ main_zone, tab_zone ], auto_generated: true)
      expect(page.composite?).to be false
    end

    it "returns false for standalone page (no model)" do
      other_zone = LcpRuby::Metadata::ZoneDefinition.new(name: "zone2", presenter: "tasks")
      page = described_class.new(name: "dashboard", zones: [ main_zone, other_zone ])
      expect(page.composite?).to be false
    end

    it "returns false for single-zone page" do
      page = described_class.new(name: "detail", model: "employee", zones: [ main_zone ])
      expect(page.composite?).to be false
    end
  end

  describe "#zones_for_area" do
    it "returns zones matching the given area" do
      sidebar_zone = LcpRuby::Metadata::ZoneDefinition.new(name: "info", presenter: "sidebar", area: "sidebar")
      tab_zone = LcpRuby::Metadata::ZoneDefinition.new(name: "tab1", presenter: "tasks", area: "tabs")
      page = described_class.new(name: "test", model: "m", zones: [ main_zone, sidebar_zone, tab_zone ])
      expect(page.zones_for_area("sidebar")).to eq([ sidebar_zone ])
      expect(page.zones_for_area("tabs")).to eq([ tab_zone ])
      expect(page.zones_for_area("main")).to eq([ main_zone ])
    end

    it "returns empty array for nonexistent area" do
      page = described_class.new(name: "test", model: "m", zones: [ main_zone ])
      expect(page.zones_for_area("sidebar")).to eq([])
    end
  end

  describe "#tab_zones and #has_tabs?" do
    it "returns tab zones" do
      tab1 = LcpRuby::Metadata::ZoneDefinition.new(name: "t1", presenter: "p1", area: "tabs")
      tab2 = LcpRuby::Metadata::ZoneDefinition.new(name: "t2", presenter: "p2", area: "tabs")
      page = described_class.new(name: "test", model: "m", zones: [ main_zone, tab1, tab2 ])
      expect(page.tab_zones).to eq([ tab1, tab2 ])
      expect(page.has_tabs?).to be true
    end

    it "returns false when no tabs" do
      page = described_class.new(name: "test", zones: [ main_zone ])
      expect(page.has_tabs?).to be false
    end
  end

  describe "#has_sidebar?" do
    it "returns true when sidebar zones exist" do
      sidebar = LcpRuby::Metadata::ZoneDefinition.new(name: "side", presenter: "p", area: "sidebar")
      page = described_class.new(name: "test", model: "m", zones: [ main_zone, sidebar ])
      expect(page.has_sidebar?).to be true
    end

    it "returns false when no sidebar zones" do
      page = described_class.new(name: "test", zones: [ main_zone ])
      expect(page.has_sidebar?).to be false
    end
  end

  describe "#has_below?" do
    it "returns true when below zones exist" do
      below = LcpRuby::Metadata::ZoneDefinition.new(name: "extra", presenter: "p", area: "below")
      page = described_class.new(name: "test", model: "m", zones: [ main_zone, below ])
      expect(page.has_below?).to be true
    end

    it "returns false when no below zones" do
      page = described_class.new(name: "test", zones: [ main_zone ])
      expect(page.has_below?).to be false
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

    it "parses a grid page with widget zones" do
      page = described_class.from_hash(
        "name" => "dashboard",
        "layout" => "grid",
        "title_key" => "dashboard.title",
        "zones" => [
          {
            "name" => "total_orders",
            "type" => "widget",
            "widget" => { "type" => "kpi_card", "model" => "order", "aggregate" => "count" },
            "position" => { "row" => 1, "col" => 1, "width" => 3, "height" => 1 }
          }
        ]
      )
      expect(page.grid?).to be true
      expect(page.standalone?).to be true
      expect(page.title_key).to eq("dashboard.title")
      expect(page.zones.first.widget?).to be true
    end
  end
end
