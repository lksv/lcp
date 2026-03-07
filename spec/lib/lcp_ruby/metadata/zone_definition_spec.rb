require "spec_helper"

RSpec.describe LcpRuby::Metadata::ZoneDefinition do
  describe ".new" do
    it "creates a presenter zone with required attributes" do
      zone = described_class.new(name: "main", presenter: "contacts")
      expect(zone.name).to eq("main")
      expect(zone.presenter).to eq("contacts")
      expect(zone.area).to eq("main")
      expect(zone.type).to eq(:presenter)
      expect(zone.presenter_zone?).to be true
      expect(zone.widget?).to be false
    end

    it "defaults area to main" do
      zone = described_class.new(name: "sidebar", presenter: "contacts")
      expect(zone.area).to eq("main")
    end

    it "accepts a custom area" do
      zone = described_class.new(name: "sidebar", presenter: "contacts", area: "sidebar")
      expect(zone.area).to eq("sidebar")
    end

    it "raises when name is blank" do
      expect {
        described_class.new(name: "", presenter: "contacts")
      }.to raise_error(LcpRuby::MetadataError, /Zone name is required/)
    end

    it "raises when presenter is blank for presenter zone" do
      expect {
        described_class.new(name: "main", presenter: "")
      }.to raise_error(LcpRuby::MetadataError, /requires a presenter reference/)
    end
  end

  describe "widget zones" do
    it "creates a kpi_card widget zone" do
      zone = described_class.new(
        name: "total_orders",
        type: :widget,
        widget: { "type" => "kpi_card", "model" => "order", "aggregate" => "count" }
      )
      expect(zone.widget?).to be true
      expect(zone.presenter_zone?).to be false
      expect(zone.widget["type"]).to eq("kpi_card")
    end

    it "creates a text widget zone" do
      zone = described_class.new(
        name: "welcome",
        type: :widget,
        widget: { "type" => "text", "content_key" => "dashboard.welcome" }
      )
      expect(zone.widget?).to be true
      expect(zone.widget["content_key"]).to eq("dashboard.welcome")
    end

    it "creates a list widget zone" do
      zone = described_class.new(
        name: "recent_tasks",
        type: :widget,
        widget: { "type" => "list", "model" => "task" }
      )
      expect(zone.widget?).to be true
    end

    it "raises when widget hash is missing for widget type" do
      expect {
        described_class.new(name: "bad", type: :widget)
      }.to raise_error(LcpRuby::MetadataError, /requires a widget configuration/)
    end

    it "raises when widget type is invalid" do
      expect {
        described_class.new(name: "bad", type: :widget, widget: { "type" => "unknown" })
      }.to raise_error(LcpRuby::MetadataError, /valid type/)
    end

    it "raises when kpi_card is missing model" do
      expect {
        described_class.new(name: "bad", type: :widget, widget: { "type" => "kpi_card", "aggregate" => "count" })
      }.to raise_error(LcpRuby::MetadataError, /requires 'model'/)
    end

    it "raises when kpi_card is missing aggregate" do
      expect {
        described_class.new(name: "bad", type: :widget, widget: { "type" => "kpi_card", "model" => "order" })
      }.to raise_error(LcpRuby::MetadataError, /requires 'aggregate'/)
    end

    it "raises when text is missing content_key" do
      expect {
        described_class.new(name: "bad", type: :widget, widget: { "type" => "text" })
      }.to raise_error(LcpRuby::MetadataError, /requires 'content_key'/)
    end

    it "raises when list is missing model" do
      expect {
        described_class.new(name: "bad", type: :widget, widget: { "type" => "list" })
      }.to raise_error(LcpRuby::MetadataError, /requires 'model'/)
    end
  end

  describe "zone attributes" do
    it "stores scope and limit" do
      zone = described_class.new(
        name: "recent",
        type: :widget,
        widget: { "type" => "list", "model" => "task" },
        scope: "recent",
        limit: 5
      )
      expect(zone.scope).to eq("recent")
      expect(zone.limit).to eq(5)
    end

    it "stores visible_when" do
      zone = described_class.new(
        name: "admin_kpi",
        type: :widget,
        widget: { "type" => "kpi_card", "model" => "order", "aggregate" => "count" },
        visible_when: { "field" => "role", "operator" => "eq", "value" => "admin" }
      )
      expect(zone.visible_when).to eq("field" => "role", "operator" => "eq", "value" => "admin")
    end
  end

  describe "#grid_position" do
    it "returns empty hash without position" do
      zone = described_class.new(name: "main", presenter: "contacts")
      expect(zone.grid_position).to eq({})
    end

    it "returns CSS grid properties from position" do
      zone = described_class.new(
        name: "kpi",
        type: :widget,
        widget: { "type" => "kpi_card", "model" => "order", "aggregate" => "count" },
        position: { "row" => 1, "col" => 1, "width" => 3, "height" => 1 }
      )
      expect(zone.grid_position).to eq(
        "grid-row" => "1 / span 1",
        "grid-column" => "1 / span 3"
      )
    end

    it "defaults span to 1" do
      zone = described_class.new(
        name: "kpi",
        type: :widget,
        widget: { "type" => "kpi_card", "model" => "order", "aggregate" => "count" },
        position: { "row" => 2, "col" => 4 }
      )
      expect(zone.grid_position).to eq(
        "grid-row" => "2 / span 1",
        "grid-column" => "4 / span 1"
      )
    end
  end

  describe ".from_hash" do
    it "parses a presenter zone hash" do
      zone = described_class.from_hash("name" => "main", "presenter" => "contacts", "area" => "sidebar")
      expect(zone.name).to eq("main")
      expect(zone.presenter).to eq("contacts")
      expect(zone.area).to eq("sidebar")
      expect(zone.presenter_zone?).to be true
    end

    it "handles symbol keys" do
      zone = described_class.from_hash(name: "main", presenter: "contacts")
      expect(zone.name).to eq("main")
      expect(zone.presenter).to eq("contacts")
    end

    it "parses a widget zone hash" do
      zone = described_class.from_hash(
        "name" => "order_count",
        "type" => "widget",
        "widget" => { "type" => "kpi_card", "model" => "order", "aggregate" => "count" },
        "position" => { "row" => 1, "col" => 1, "width" => 3, "height" => 1 },
        "visible_when" => { "field" => "role", "operator" => "eq", "value" => "admin" }
      )
      expect(zone.widget?).to be true
      expect(zone.widget["model"]).to eq("order")
      expect(zone.position).to eq("row" => 1, "col" => 1, "width" => 3, "height" => 1)
      expect(zone.visible_when).to be_a(Hash)
    end
  end
end
