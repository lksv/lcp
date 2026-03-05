require "spec_helper"
require "support/integration_helper"

RSpec.describe "Tiles Index View", type: :request do
  before(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("tiles")
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("tiles")
  end

  before(:each) do
    load_integration_metadata!("tiles")
    stub_current_user(role: "admin")

    product_class = LcpRuby.registry.model_for("product")
    product_class.delete_all
    product_class.create!(name: "Widget A", description: "A great widget", price: 29.99, category: "Widgets", status: "active", image_url: "https://example.com/a.jpg", quantity: 100)
    product_class.create!(name: "Gadget B", description: "A fine gadget", price: 49.99, category: "Gadgets", status: "draft", quantity: 50)
    product_class.create!(name: "Gizmo C", price: 9.99, category: "Widgets", status: "archived", quantity: 200)
  end

  describe "GET /products (tiles layout)" do
    it "renders the tiles grid" do
      get "/products"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-tiles-grid")
    end

    it "renders tile cards with title fields" do
      get "/products"
      expect(response.body).to include("lcp-tile-card")
      expect(response.body).to include("Widget A")
      expect(response.body).to include("Gadget B")
      expect(response.body).to include("Gizmo C")
    end

    it "renders tile title as link when card_link: show" do
      get "/products"
      expect(response.body).to include("lcp-tile-title")
      # Title should be a link to show page
      expect(response.body).to match(%r{<a href="/products/\d+">Widget A</a>})
    end

    it "renders subtitle field" do
      get "/products"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-tile-subtitle")
    end

    it "renders description field with line clamping" do
      get "/products"
      expect(response.body).to include("lcp-tile-description")
      expect(response.body).to include("A great widget")
      expect(response.body).to include("--lcp-tile-desc-lines: 2")
    end

    it "renders tile fields (label-value pairs)" do
      get "/products"
      expect(response.body).to include("lcp-tile-fields")
      expect(response.body).to include("Price")
    end

    it "renders actions dropdown in tile cards" do
      get "/products"
      expect(response.body).to include("lcp-tile-actions")
      expect(response.body).to include("lcp-actions-dropdown")
    end

    it "renders the sort dropdown" do
      get "/products"
      expect(response.body).to include("lcp-sort-dropdown")
      expect(response.body).to include("Name")
      expect(response.body).to include("Price")
      expect(response.body).to include("Date Added")
    end

    it "renders the per-page selector" do
      get "/products"
      expect(response.body).to include("lcp-per-page-selector")
    end

    it "renders the summary bar" do
      get "/products"
      expect(response.body).to include("lcp-summary-bar")
      expect(response.body).to include("Total Value")
      expect(response.body).to include("Average Price")
    end

    it "respects per_page parameter" do
      get "/products", params: { per_page: 6 }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-tiles-grid")
    end

    it "ignores invalid per_page values" do
      get "/products", params: { per_page: 999 }
      expect(response).to have_http_status(:ok)
    end

    it "supports sort parameter" do
      get "/products", params: { sort: "price", direction: "desc" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-tiles-grid")
    end

    it "supports quick search" do
      get "/products", params: { qs: "Widget" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Widget A")
    end

    it "shows empty state when no records match" do
      get "/products", params: { qs: "nonexistent_product_xyz" }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /products (pagination)" do
    it "paginates tile results" do
      get "/products", params: { per_page: 6 }
      expect(response).to have_http_status(:ok)
      # All 3 records fit in one page of 6
      expect(response.body).to include("Widget A")
      expect(response.body).to include("Gadget B")
      expect(response.body).to include("Gizmo C")
    end
  end
end
