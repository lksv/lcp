require "spec_helper"
require "support/integration_helper"

RSpec.describe LcpRuby::Widgets::DataResolver do
  include IntegrationHelper

  before(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("dashboard")
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("dashboard")
  end

  before(:each) do
    load_integration_metadata!("dashboard")
  end

  let(:admin_user) do
    OpenStruct.new(id: 1, lcp_role: ["admin"], name: "Admin")
  end

  let(:task_model) { LcpRuby.registry.model_for("dashboard_task") }
  let(:order_model) { LcpRuby.registry.model_for("dashboard_order") }

  describe "kpi_card widget" do
    let(:zone) do
      LcpRuby::Metadata::ZoneDefinition.new(
        name: "total_orders",
        type: :widget,
        widget: { "type" => "kpi_card", "model" => "dashboard_order", "aggregate" => "count" }
      )
    end

    it "returns the count of records" do
      order_model.create!(name: "Order 1", total_amount: 100)
      order_model.create!(name: "Order 2", total_amount: 200)

      result = described_class.new(zone, user: admin_user).resolve
      expect(result[:value]).to eq(2)
      expect(result[:label]).to be_present
    end

    it "supports sum aggregate with field" do
      order_model.create!(name: "Order 1", total_amount: 100.5)
      order_model.create!(name: "Order 2", total_amount: 200.0)

      zone = LcpRuby::Metadata::ZoneDefinition.new(
        name: "total_revenue",
        type: :widget,
        widget: { "type" => "kpi_card", "model" => "dashboard_order", "aggregate" => "sum", "aggregate_field" => "total_amount" }
      )

      result = described_class.new(zone, user: admin_user).resolve
      expect(result[:value]).to be_within(0.01).of(300.5)
    end

    it "returns hidden when evaluator cannot be built" do
      # Use a zone referencing a non-existent model
      bad_zone = LcpRuby::Metadata::ZoneDefinition.new(
        name: "bad",
        type: :widget,
        widget: { "type" => "kpi_card", "model" => "nonexistent_model", "aggregate" => "count" }
      )
      result = described_class.new(bad_zone, user: admin_user).resolve
      expect(result[:hidden]).to be true
    end
  end

  describe "text widget" do
    let(:zone) do
      LcpRuby::Metadata::ZoneDefinition.new(
        name: "welcome",
        type: :widget,
        widget: { "type" => "text", "content_key" => "lcp_ruby.dashboard.welcome" }
      )
    end

    it "returns i18n content" do
      result = described_class.new(zone, user: admin_user).resolve
      expect(result[:content]).to be_a(String)
    end
  end

  describe "list widget" do
    let(:zone) do
      LcpRuby::Metadata::ZoneDefinition.new(
        name: "recent_tasks",
        type: :widget,
        widget: { "type" => "list", "model" => "dashboard_task" },
        limit: 3
      )
    end

    it "returns limited records" do
      5.times { |i| task_model.create!(name: "Task #{i}", status: "open") }

      result = described_class.new(zone, user: admin_user).resolve
      expect(result[:records].length).to eq(3)
      expect(result[:model_name]).to eq("dashboard_task")
    end
  end

  describe "zone scope" do
    it "applies named scope to kpi_card" do
      task_model.create!(name: "Open", status: "open")
      task_model.create!(name: "Closed", status: "closed")

      zone = LcpRuby::Metadata::ZoneDefinition.new(
        name: "open_count",
        type: :widget,
        widget: { "type" => "kpi_card", "model" => "dashboard_task", "aggregate" => "count" },
        scope: "open_tasks"
      )

      result = described_class.new(zone, user: admin_user).resolve
      expect(result[:value]).to eq(1)
    end
  end
end
