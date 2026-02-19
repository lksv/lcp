require "spec_helper"
require "support/integration_helper"

RSpec.describe "Tree Select (Phase 4)", type: :request do
  before(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("tree")
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("tree")
  end

  before(:each) do
    load_integration_metadata!("tree")
    LcpRuby.registry.model_for("category").delete_all
    stub_current_user(role: "admin")
  end

  let(:category_model) { LcpRuby.registry.model_for("category") }

  describe "tree_select form rendering" do
    it "renders new form with tree select widget" do
      get "/admin/categories/new"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-tree-select-wrapper")
      expect(response.body).to include("lcp-tree-trigger")
      expect(response.body).to include("lcp-tree-dropdown")
    end

    it "renders edit form with tree select showing current value" do
      root = category_model.create!(name: "Root")
      child = category_model.create!(name: "Child", parent_id: root.id)

      get "/admin/categories/#{child.id}/edit"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-tree-select-wrapper")
      expect(response.body).to include("Root")
    end
  end

  describe "creating records with tree select" do
    it "creates a root category (no parent)" do
      expect {
        post "/admin/categories", params: {
          record: { name: "Root Category", active: true }
        }
      }.to change { category_model.count }.by(1)

      cat = category_model.last
      expect(cat.name).to eq("Root Category")
      expect(cat.parent_id).to be_nil
    end

    it "creates a child category with parent_id" do
      root = category_model.create!(name: "Root")

      expect {
        post "/admin/categories", params: {
          record: { name: "Child Category", parent_id: root.id, active: true }
        }
      }.to change { category_model.count }.by(1)

      child = category_model.last
      expect(child.name).to eq("Child Category")
      expect(child.parent_id).to eq(root.id)
    end
  end

  describe "updating records with tree select" do
    it "updates parent_id" do
      root1 = category_model.create!(name: "Root 1")
      root2 = category_model.create!(name: "Root 2")
      child = category_model.create!(name: "Child", parent_id: root1.id)

      patch "/admin/categories/#{child.id}", params: {
        record: { parent_id: root2.id }
      }

      expect(response).to have_http_status(:redirect)
      child.reload
      expect(child.parent_id).to eq(root2.id)
    end

    it "clears parent_id to make a root category" do
      root = category_model.create!(name: "Root")
      child = category_model.create!(name: "Child", parent_id: root.id)

      patch "/admin/categories/#{child.id}", params: {
        record: { parent_id: "" }
      }

      expect(response).to have_http_status(:redirect)
      child.reload
      expect(child.parent_id).to be_nil
    end
  end

  describe "tree select_options endpoint" do
    it "returns tree JSON when tree=true" do
      root = category_model.create!(name: "Root")
      child = category_model.create!(name: "Child", parent_id: root.id)
      grandchild = category_model.create!(name: "Grandchild", parent_id: child.id)

      get "/admin/categories/select_options", params: { field: "parent_id", tree: "true" }
      expect(response).to have_http_status(:ok)

      data = JSON.parse(response.body)
      expect(data).to be_an(Array)
      expect(data.length).to eq(1) # Only root at top level

      root_node = data.first
      expect(root_node["id"]).to eq(root.id)
      expect(root_node["label"]).to eq("Root")
      expect(root_node["children"].length).to eq(1)

      child_node = root_node["children"].first
      expect(child_node["id"]).to eq(child.id)
      expect(child_node["children"].length).to eq(1)

      grandchild_node = child_node["children"].first
      expect(grandchild_node["id"]).to eq(grandchild.id)
      expect(grandchild_node["children"]).to eq([])
    end
  end
end
