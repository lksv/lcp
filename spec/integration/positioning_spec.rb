require "spec_helper"
require "support/integration_helper"
require "digest"

RSpec.describe "Record Positioning Integration", type: :request do
  before(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("positioning")
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("positioning")
  end

  before(:each) do
    load_integration_metadata!("positioning")
    stub_current_user(role: "admin")
    LcpRuby.registry.model_for("priority").delete_all
    LcpRuby.registry.model_for("stage").delete_all
    LcpRuby.registry.model_for("pipeline").delete_all
  end

  let(:priority_model) { LcpRuby.registry.model_for("priority") }
  let(:stage_model) { LcpRuby.registry.model_for("stage") }
  let(:pipeline_model) { LcpRuby.registry.model_for("pipeline") }

  # --- Index page ---

  describe "GET /priorities (index)" do
    it "renders drag handles when reorderable" do
      priority_model.create!(label: "High")
      priority_model.create!(label: "Medium")

      get "/priorities"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-drag-handle")
      expect(response.body).to include("data-reorder-url")
      expect(response.body).to include("data-list-version")
    end

    it "renders records sorted by position by default" do
      c = priority_model.create!(label: "Low")
      a = priority_model.create!(label: "High")
      b = priority_model.create!(label: "Medium")

      # Move "High" to first position
      a.update!(position: 1)

      get "/priorities"

      expect(response).to have_http_status(:ok)
      body = response.body

      # High should appear before Low and Medium in the response
      pos_high = body.index("High")
      pos_low = body.index("Low")
      pos_medium = body.index("Medium")
      expect(pos_high).to be < pos_low
      expect(pos_high).to be < pos_medium
    end

    it "does not render drag handles for non-reorderable model" do
      pipeline_model.create!(name: "Sales")

      get "/pipelines"

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("lcp-drag-handle")
      expect(response.body).not_to include("data-reorder-url")
    end
  end

  # --- Reorder action ---

  describe "PATCH /priorities/:id/reorder" do
    it "returns 200 and updates position" do
      a = priority_model.create!(label: "High")
      b = priority_model.create!(label: "Medium")
      c = priority_model.create!(label: "Low")

      patch "/priorities/#{c.id}/reorder",
            params: { position: 1 },
            as: :json

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json["position"]).to be_a(Integer)
      expect(json["list_version"]).to be_a(String)
    end

    it "supports relative positioning with after" do
      a = priority_model.create!(label: "First")
      b = priority_model.create!(label: "Second")
      c = priority_model.create!(label: "Third")

      # Move Third to after First
      patch "/priorities/#{c.id}/reorder",
            params: { position: { after: a.id } },
            as: :json

      expect(response).to have_http_status(:ok)

      # Reload and check order
      expect(a.reload.position).to eq(1)
      expect(c.reload.position).to eq(2)
      expect(b.reload.position).to eq(3)
    end

    it "supports relative positioning with before" do
      a = priority_model.create!(label: "First")
      b = priority_model.create!(label: "Second")
      c = priority_model.create!(label: "Third")

      # Move Third to before Second
      patch "/priorities/#{c.id}/reorder",
            params: { position: { before: b.id } },
            as: :json

      expect(response).to have_http_status(:ok)

      expect(a.reload.position).to eq(1)
      expect(c.reload.position).to eq(2)
      expect(b.reload.position).to eq(3)
    end

    it "returns 404 for non-positioned model" do
      pipeline = pipeline_model.create!(name: "Sales")

      patch "/pipelines/#{pipeline.id}/reorder",
            params: { position: 1 },
            as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "returns 403 for viewer role" do
      stub_current_user(role: "viewer")
      p = priority_model.create!(label: "High")

      patch "/priorities/#{p.id}/reorder",
            params: { position: 1 },
            as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it "returns 409 for stale list_version" do
      a = priority_model.create!(label: "High")
      b = priority_model.create!(label: "Medium")

      patch "/priorities/#{b.id}/reorder",
            params: { position: 1, list_version: "stale_hash_value" },
            as: :json

      expect(response).to have_http_status(:conflict)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("list_version_mismatch")
    end

    it "succeeds with matching list_version" do
      a = priority_model.create!(label: "High")
      b = priority_model.create!(label: "Medium")

      # Compute the current list version
      ids_in_order = priority_model.order(position: :asc).pluck(:id)
      current_version = Digest::SHA256.hexdigest(ids_in_order.join(","))

      patch "/priorities/#{b.id}/reorder",
            params: { position: 1, list_version: current_version },
            as: :json

      expect(response).to have_http_status(:ok)
    end
  end

  # --- Scoped reorder ---

  describe "scoped reorder (stages within pipelines)" do
    it "reorders within scope independently" do
      sales = pipeline_model.create!(name: "Sales")
      support = pipeline_model.create!(name: "Support")

      s1 = stage_model.create!(name: "Lead", pipeline_id: sales.id)
      s2 = stage_model.create!(name: "Qualified", pipeline_id: sales.id)
      s3 = stage_model.create!(name: "Closed", pipeline_id: sales.id)

      t1 = stage_model.create!(name: "Open", pipeline_id: support.id)
      t2 = stage_model.create!(name: "Resolved", pipeline_id: support.id)

      # Move Closed to first position in Sales pipeline
      patch "/stages/#{s3.id}/reorder",
            params: { position: 1 },
            as: :json

      expect(response).to have_http_status(:ok)

      # Sales pipeline reordered
      expect(s3.reload.position).to eq(1)
      expect(s1.reload.position).to eq(2)
      expect(s2.reload.position).to eq(3)

      # Support pipeline unaffected
      expect(t1.reload.position).to eq(1)
      expect(t2.reload.position).to eq(2)
    end
  end

  # --- Index with viewer role ---

  describe "drag handles visibility" do
    it "does not render drag handles for viewer role" do
      stub_current_user(role: "viewer")
      priority_model.create!(label: "High")

      get "/priorities"

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("lcp-drag-handle")
    end
  end

  # --- Position auto-assignment on create ---

  describe "position auto-assignment" do
    it "auto-assigns position on record create" do
      post "/priorities", params: { record: { label: "First" } }
      follow_redirect!
      post "/priorities", params: { record: { label: "Second" } }
      follow_redirect!

      records = priority_model.order(position: :asc)
      expect(records.first.label).to eq("First")
      expect(records.first.position).to eq(1)
      expect(records.last.label).to eq("Second")
      expect(records.last.position).to eq(2)
    end
  end

  # --- Reorder disabled state ---

  describe "reorder disabled state" do
    it "disables drag handles when search query is active" do
      priority_model.create!(label: "High")
      priority_model.create!(label: "Medium")

      get "/priorities", params: { q: "High" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-drag-handle")
      expect(response.body).to include('data-reorder-disabled="true"')
    end

    it "disables drag handles when sorting by non-position column" do
      priority_model.create!(label: "High")
      priority_model.create!(label: "Medium")

      get "/priorities", params: { sort: "label", direction: "asc" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-drag-handle")
      expect(response.body).to include('data-reorder-disabled="true"')
    end

    it "does not disable drag handles when sorting by position column" do
      priority_model.create!(label: "High")
      priority_model.create!(label: "Medium")

      get "/priorities", params: { sort: "position", direction: "asc" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lcp-drag-handle")
      expect(response.body).not_to include('data-reorder-disabled="true"')
    end
  end

  # --- List version ---

  describe "list_version" do
    def compute_version(model, scope_filter: {})
      scope = model.all
      scope_filter.each { |col, val| scope = scope.where(col => val) }
      ids = scope.order(position: :asc).pluck(:id)
      Digest::SHA256.hexdigest(ids.join(","))
    end

    it "changes list_version when a record is created" do
      a = priority_model.create!(label: "First")
      version_before = compute_version(priority_model)

      priority_model.create!(label: "Second")
      version_after = compute_version(priority_model)

      expect(version_after).not_to eq(version_before)
    end

    it "changes list_version when a record is destroyed" do
      a = priority_model.create!(label: "First")
      b = priority_model.create!(label: "Second")
      version_before = compute_version(priority_model)

      b.destroy!
      version_after = compute_version(priority_model)

      expect(version_after).not_to eq(version_before)
    end

    it "changes list_version after a reorder" do
      a = priority_model.create!(label: "First")
      b = priority_model.create!(label: "Second")
      c = priority_model.create!(label: "Third")
      version_before = compute_version(priority_model)

      patch "/priorities/#{c.id}/reorder",
            params: { position: 1 },
            as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["list_version"]).not_to eq(version_before)
    end

    it "returns updated list_version in reorder response" do
      a = priority_model.create!(label: "First")
      b = priority_model.create!(label: "Second")

      patch "/priorities/#{b.id}/reorder",
            params: { position: 1 },
            as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      # Response version matches freshly computed version
      expected = compute_version(priority_model)
      expect(json["list_version"]).to eq(expected)
    end

    it "scoped list_version is unaffected by changes in a different scope" do
      sales = pipeline_model.create!(name: "Sales")
      support = pipeline_model.create!(name: "Support")

      s1 = stage_model.create!(name: "Lead", pipeline_id: sales.id)
      s2 = stage_model.create!(name: "Qualified", pipeline_id: sales.id)
      t1 = stage_model.create!(name: "Open", pipeline_id: support.id)

      support_version_before = compute_version(stage_model, scope_filter: { pipeline_id: support.id })

      # Reorder in Sales scope
      patch "/stages/#{s2.id}/reorder",
            params: { position: 1 },
            as: :json

      expect(response).to have_http_status(:ok)

      # Support scope version unchanged
      support_version_after = compute_version(stage_model, scope_filter: { pipeline_id: support.id })
      expect(support_version_after).to eq(support_version_before)
    end

    it "includes data-list-version attribute on the table" do
      priority_model.create!(label: "First")
      priority_model.create!(label: "Second")

      get "/priorities"

      expect(response).to have_http_status(:ok)
      expected_version = compute_version(priority_model)
      expect(response.body).to include("data-list-version=\"#{expected_version}\"")
    end

    it "computes list_version from all records, not just current page" do
      # Create more records than fit on a page
      6.times { |i| priority_model.create!(label: "Priority #{i + 1}") }

      # Request with small per_page (priorities presenter uses default, simulate via many records)
      get "/priorities"

      expect(response).to have_http_status(:ok)
      # The version in the page should match the full-scope version
      expected_version = compute_version(priority_model)
      expect(response.body).to include("data-list-version=\"#{expected_version}\"")
    end
  end
end
