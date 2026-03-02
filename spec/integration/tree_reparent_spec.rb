require "spec_helper"
require "support/integration_helper"

RSpec.describe "Tree Reparent", type: :request do
  include IntegrationHelper

  before do
    load_integration_metadata!("tree")
    stub_current_user(role: "admin")
  end

  let(:model_class) { LcpRuby.registry.model_for("category") }

  describe "PATCH reparent" do
    it "changes parent_id and returns tree_version" do
      root = model_class.create!(name: "Root")
      child = model_class.create!(name: "Child")

      patch "/categories/#{child.id}/reparent",
        params: { parent_id: root.id },
        headers: { "Accept" => "application/json" },
        as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["id"]).to eq(child.id)
      expect(json["parent_id"]).to eq(root.id)
      expect(json["tree_version"]).to be_present

      child.reload
      expect(child.parent_id).to eq(root.id)
    end

    it "moves to root with null parent_id" do
      root = model_class.create!(name: "Root")
      child = model_class.create!(name: "Child", parent_id: root.id)

      patch "/categories/#{child.id}/reparent",
        params: { parent_id: nil },
        headers: { "Accept" => "application/json" },
        as: :json

      expect(response).to have_http_status(:ok)
      child.reload
      expect(child.parent_id).to be_nil
    end

    it "moves to root with 'null' string parent_id" do
      root = model_class.create!(name: "Root")
      child = model_class.create!(name: "Child", parent_id: root.id)

      patch "/categories/#{child.id}/reparent",
        params: { parent_id: "null" },
        headers: { "Accept" => "application/json" },
        as: :json

      expect(response).to have_http_status(:ok)
      child.reload
      expect(child.parent_id).to be_nil
    end

    it "returns 422 when creating a cycle" do
      parent = model_class.create!(name: "Parent")
      child = model_class.create!(name: "Child", parent_id: parent.id)

      patch "/categories/#{parent.id}/reparent",
        params: { parent_id: child.id },
        headers: { "Accept" => "application/json" },
        as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["errors"]).to be_present

      parent.reload
      expect(parent.parent_id).to be_nil
    end

    it "returns 422 for self-referencing parent" do
      node = model_class.create!(name: "Node")

      patch "/categories/#{node.id}/reparent",
        params: { parent_id: node.id },
        headers: { "Accept" => "application/json" },
        as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["errors"]).to be_present
    end

    it "moves subtree correctly" do
      root1 = model_class.create!(name: "Root1")
      root2 = model_class.create!(name: "Root2")
      child = model_class.create!(name: "Child", parent_id: root1.id)
      grandchild = model_class.create!(name: "Grandchild", parent_id: child.id)

      patch "/categories/#{child.id}/reparent",
        params: { parent_id: root2.id },
        headers: { "Accept" => "application/json" },
        as: :json

      expect(response).to have_http_status(:ok)

      child.reload
      grandchild.reload
      expect(child.parent_id).to eq(root2.id)
      # Grandchild stays under child (subtree moves together)
      expect(grandchild.parent_id).to eq(child.id)
    end

    it "returns 409 for stale tree_version" do
      root = model_class.create!(name: "Root")
      child = model_class.create!(name: "Child")

      patch "/categories/#{child.id}/reparent",
        params: { parent_id: root.id, tree_version: "stale_version_hash" },
        headers: { "Accept" => "application/json" },
        as: :json

      expect(response).to have_http_status(:conflict)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("tree_version_mismatch")
      expect(json["tree_version"]).to be_present
    end

    it "succeeds with correct tree_version" do
      root = model_class.create!(name: "Root")
      child = model_class.create!(name: "Child")

      # Compute the current tree version
      pairs = model_class.order(:id).pluck(:id, :parent_id)
      version = Digest::SHA256.hexdigest(pairs.map { |id, pid| "#{id}:#{pid}" }.join(","))

      patch "/categories/#{child.id}/reparent",
        params: { parent_id: root.id, tree_version: version },
        headers: { "Accept" => "application/json" },
        as: :json

      expect(response).to have_http_status(:ok)
    end

    it "returns 404 when model is not a tree" do
      node = model_class.create!(name: "Node")

      allow_any_instance_of(LcpRuby::Metadata::ModelDefinition)
        .to receive(:tree?).and_return(false)

      patch "/categories/#{node.id}/reparent",
        params: { parent_id: nil },
        headers: { "Accept" => "application/json" },
        as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "permission checks" do
    it "returns 403 when user cannot update records" do
      node = model_class.create!(name: "Node")

      # Stub a viewer role that can only read
      allow_any_instance_of(LcpRuby::Authorization::PermissionEvaluator)
        .to receive(:can?).with(:update).and_return(false)

      patch "/categories/#{node.id}/reparent",
        params: { parent_id: nil },
        headers: { "Accept" => "application/json" },
        as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it "returns 403 when parent_id field is not writable" do
      node = model_class.create!(name: "Node")

      allow_any_instance_of(LcpRuby::Authorization::PermissionEvaluator)
        .to receive(:field_writable?).with("parent_id").and_return(false)

      patch "/categories/#{node.id}/reparent",
        params: { parent_id: nil },
        headers: { "Accept" => "application/json" },
        as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "drag handles rendering" do
    it "renders drag handles when reparentable and authorized" do
      model_class.create!(name: "Root")

      allow_any_instance_of(LcpRuby::Metadata::PresenterDefinition)
        .to receive(:reparentable?).and_return(true)

      get "/categories"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-drag-handle")
      expect(response.body).to include("data-reparent-url")
      expect(response.body).to include("data-subtree-ids")
      expect(response.body).to include("data-tree-version")
    end

    it "renders root drop zone when reparentable" do
      model_class.create!(name: "Root")

      allow_any_instance_of(LcpRuby::Metadata::PresenterDefinition)
        .to receive(:reparentable?).and_return(true)

      get "/categories"

      expect(response.body).to include("lcp-tree-root-drop-zone")
      expect(response.body).to include("Drop here to make root")
    end

    it "hides drag handles during search" do
      model_class.create!(name: "Root")

      allow_any_instance_of(LcpRuby::Metadata::PresenterDefinition)
        .to receive(:reparentable?).and_return(true)

      get "/categories?qs=Root"

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("lcp-drag-handle")
      expect(response.body).not_to include("data-reparent-url")
      expect(response.body).not_to include("lcp-tree-root-drop-zone")
    end

    it "does not render drag handles when reparentable is false" do
      model_class.create!(name: "Root")
      get "/categories"

      expect(response.body).not_to include("lcp-drag-handle")
      expect(response.body).not_to include("data-reparent-url")
      expect(response.body).not_to include("lcp-tree-root-drop-zone")
    end
  end
end
