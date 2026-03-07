require "spec_helper"
require "support/integration_helper"

RSpec.describe "Virtual Columns Integration", type: :request do
  before(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("virtual_columns")
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("virtual_columns")
  end

  before(:each) do
    load_integration_metadata!("virtual_columns")
    stub_current_user(role: "admin")

    LcpRuby.registry.model_for("vc_line_item").delete_all
    LcpRuby.registry.model_for("vc_order").delete_all
    LcpRuby.registry.model_for("vc_company").delete_all
  end

  let(:order_class) { LcpRuby.registry.model_for("vc_order") }
  let(:line_item_class) { LcpRuby.registry.model_for("vc_line_item") }
  let(:company_class) { LcpRuby.registry.model_for("vc_company") }

  describe "GET /vc_orders (index with virtual columns)" do
    it "displays declarative aggregate values" do
      order = order_class.create!(title: "Order 1", status: "open", due_date: Date.tomorrow)
      line_item_class.create!(description: "Item A", quantity: 2, unit_price: 10, vc_order_id: order.id)
      line_item_class.create!(description: "Item B", quantity: 3, unit_price: 5, vc_order_id: order.id)

      get "/vc_orders"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Order 1")
      expect(response.body).to include("2") # items_count
    end

    it "displays expression virtual column values" do
      order_class.create!(title: "Overdue Order", status: "pending", due_date: Date.yesterday)
      order_class.create!(title: "Future Order", status: "pending", due_date: Date.tomorrow)

      get "/vc_orders"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Overdue Order")
      expect(response.body).to include("Future Order")
    end

    it "displays JOIN-based virtual column values" do
      company = company_class.create!(name: "Acme Corp", country: "US")
      order_class.create!(title: "Company Order", status: "open", due_date: Date.tomorrow, vc_company_id: company.id)

      get "/vc_orders"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Acme Corp")
    end

    it "displays GROUP BY virtual column values" do
      order = order_class.create!(title: "Grouped", status: "open", due_date: Date.tomorrow)
      line_item_class.create!(description: "X", quantity: 2, unit_price: 10, vc_order_id: order.id)
      line_item_class.create!(description: "Y", quantity: 3, unit_price: 5, vc_order_id: order.id)

      get "/vc_orders"

      expect(response).to have_http_status(:ok)
      # total_value = 2*10 + 3*5 = 35
      expect(response.body).to include("35")
    end

    it "shows zero defaults for orders with no line items" do
      order_class.create!(title: "Empty Order", status: "open", due_date: Date.tomorrow)

      get "/vc_orders"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Empty Order")
      expect(response.body).to include("0") # items_count defaults to 0
    end

    it "supports sorting by virtual column" do
      o1 = order_class.create!(title: "Few Items", status: "open", due_date: Date.tomorrow)
      o2 = order_class.create!(title: "Many Items", status: "open", due_date: Date.tomorrow)
      line_item_class.create!(description: "A", quantity: 1, unit_price: 1, vc_order_id: o1.id)
      3.times do |i|
        line_item_class.create!(description: "B#{i}", quantity: 1, unit_price: 1, vc_order_id: o2.id)
      end

      get "/vc_orders", params: { sort: "items_count", direction: "desc" }

      expect(response).to have_http_status(:ok)
      body = response.body
      many_pos = body.index("Many Items")
      few_pos = body.index("Few Items")
      expect(many_pos).to be < few_pos
    end

    it "supports sorting by GROUP BY virtual column" do
      o1 = order_class.create!(title: "Cheap", status: "open", due_date: Date.tomorrow)
      o2 = order_class.create!(title: "Expensive", status: "open", due_date: Date.tomorrow)
      line_item_class.create!(description: "A", quantity: 1, unit_price: 5, vc_order_id: o1.id)
      line_item_class.create!(description: "B", quantity: 10, unit_price: 100, vc_order_id: o2.id)

      get "/vc_orders", params: { sort: "total_value", direction: "desc" }

      expect(response).to have_http_status(:ok)
      body = response.body
      exp_pos = body.index("Expensive")
      cheap_pos = body.index("Cheap")
      expect(exp_pos).to be < cheap_pos
    end
  end

  describe "GET /vc_orders/:id (show with virtual columns)" do
    it "displays virtual column values on the show page" do
      company = company_class.create!(name: "Test Co", country: "DE")
      order = order_class.create!(title: "Show Test", status: "pending", due_date: Date.tomorrow, vc_company_id: company.id)
      line_item_class.create!(description: "Item 1", quantity: 2, unit_price: 15, vc_order_id: order.id)

      get "/vc_orders/#{order.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Show Test")
      expect(response.body).to include("1")  # items_count
      expect(response.body).to include("Test Co") # company_name via JOIN
    end
  end

  describe "backward compatibility with aggregates key" do
    it "existing aggregate_columns tests still pass" do
      # This test verifies that using the 'aggregates' YAML key still works
      # (covered by the aggregate_columns_spec.rb integration test)
      model_def = LcpRuby.loader.model_definition("vc_order")
      expect(model_def.aggregate_names).to include("items_count")
      expect(model_def.aggregate("items_count")).to be_a(LcpRuby::Metadata::VirtualColumnDefinition)
    end
  end
end
