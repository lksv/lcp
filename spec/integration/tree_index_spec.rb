require "spec_helper"
require "support/integration_helper"

RSpec.describe "Tree Index View", type: :request do
  include IntegrationHelper

  before do
    load_integration_metadata!("tree")
    stub_current_user(role: "admin")
  end

  let(:model_class) { LcpRuby.registry.model_for("category") }

  describe "tree view rendering" do
    it "renders tree table with data-lcp-tree-index attribute" do
      model_class.create!(name: "Root")
      get "/categories"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("data-lcp-tree-index")
      expect(response.body).to include("lcp-tree-table")
    end

    it "renders root nodes at depth 0" do
      root = model_class.create!(name: "Root Node")
      get "/categories"

      expect(response.body).to include("data-depth=\"0\"")
      expect(response.body).to include("data-record-id=\"#{root.id}\"")
    end

    it "renders children with increasing depth" do
      root = model_class.create!(name: "Root")
      child = model_class.create!(name: "Child", parent_id: root.id)
      grandchild = model_class.create!(name: "Grandchild", parent_id: child.id)

      get "/categories"

      expect(response.body).to include("data-record-id=\"#{root.id}\"")
      expect(response.body).to include("data-record-id=\"#{child.id}\"")
      expect(response.body).to include("data-record-id=\"#{grandchild.id}\"")
      expect(response.body).to include("data-depth=\"0\"")
      expect(response.body).to include("data-depth=\"1\"")
      expect(response.body).to include("data-depth=\"2\"")
    end

    it "renders chevron toggles for non-leaf nodes" do
      root = model_class.create!(name: "Root")
      model_class.create!(name: "Child", parent_id: root.id)

      get "/categories"

      expect(response.body).to include("lcp-tree-chevron")
      expect(response.body).to include("data-lcp-tree-toggle=\"#{root.id}\"")
    end

    it "renders leaf spacers for leaf nodes" do
      model_class.create!(name: "Leaf")
      get "/categories"

      expect(response.body).to include("lcp-tree-leaf-spacer")
    end

    it "renders with no pagination" do
      20.times { |i| model_class.create!(name: "Item #{i}") }
      get "/categories"

      # All items should be rendered (tree view has no pagination)
      expect(response.body.scan("data-record-id").count).to eq(20)
    end

    it "respects default_expanded setting" do
      model_class.create!(name: "Root")
      get "/categories"

      expect(response.body).to include('data-default-expanded="1"')
    end

    it "renders empty state when no records" do
      get "/categories"

      expect(response).to have_http_status(:ok)
    end
  end

  describe "tree view with search" do
    it "returns filtered tree showing matches and ancestors" do
      root = model_class.create!(name: "Electronics")
      child = model_class.create!(name: "Phones", parent_id: root.id)
      model_class.create!(name: "iPhone", parent_id: child.id)
      model_class.create!(name: "Clothing")

      get "/categories?qs=iPhone"

      expect(response).to have_http_status(:ok)
      # Should include iPhone and its ancestors (Phones, Electronics)
      expect(response.body).to include("iPhone")
      expect(response.body).to include("Phones")
      expect(response.body).to include("Electronics")
      # Clothing should not be in the filtered tree
      expect(response.body).not_to include("Clothing")
    end

    it "marks ancestor-context rows with CSS class" do
      root = model_class.create!(name: "Electronics")
      child = model_class.create!(name: "Phones", parent_id: root.id)
      model_class.create!(name: "iPhone", parent_id: child.id)

      get "/categories?qs=iPhone"

      expect(response.body).to include("lcp-tree-ancestor-context")
    end

    it "sets search-active data attribute during search" do
      model_class.create!(name: "Test")
      get "/categories?qs=Test"

      expect(response.body).to include('data-search-active="true"')
    end
  end

  describe "no drag handles in read-only tree" do
    it "does not render drag handles when reparentable is false" do
      model_class.create!(name: "Root")
      get "/categories"

      expect(response.body).not_to include("lcp-drag-handle")
    end
  end

  describe "show page with tree associations" do
    it "renders show page with children association_list (strict_loading)" do
      root = model_class.create!(name: "Electronics")
      model_class.create!(name: "Phones", parent_id: root.id)
      model_class.create!(name: "Laptops", parent_id: root.id)

      get "/categories/#{root.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Electronics")
      expect(response.body).to include("Subcategories")
      expect(response.body).to include("Phones")
      expect(response.body).to include("Laptops")
    end

    it "renders show page for leaf node without errors" do
      root = model_class.create!(name: "Root")
      leaf = model_class.create!(name: "Leaf", parent_id: root.id)

      get "/categories/#{leaf.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Leaf")
      expect(response.body).to include("No subcategories.")
    end
  end
end
