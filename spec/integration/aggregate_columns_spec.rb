require "spec_helper"
require "support/integration_helper"

RSpec.describe "Aggregate Columns Integration", type: :request do
  before(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("aggregate_columns")
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("aggregate_columns")
  end

  before(:each) do
    load_integration_metadata!("aggregate_columns")
    stub_current_user(role: "admin")

    # Clear records
    LcpRuby.registry.model_for("agg_issue").delete_all
    LcpRuby.registry.model_for("agg_project").delete_all
  end

  let(:project_class) { LcpRuby.registry.model_for("agg_project") }
  let(:issue_class) { LcpRuby.registry.model_for("agg_issue") }

  describe "GET /agg_projects (index with aggregates)" do
    it "displays aggregate values in the table" do
      project = project_class.create!(name: "Alpha")
      issue_class.create!(title: "Bug 1", status: "open", priority: 3, estimated_hours: 4.5, agg_project_id: project.id)
      issue_class.create!(title: "Bug 2", status: "closed", priority: 1, estimated_hours: 2.0, agg_project_id: project.id)
      issue_class.create!(title: "Feature 1", status: "open", priority: 5, estimated_hours: 8.0, agg_project_id: project.id)

      get "/agg_projects"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Alpha")
      # Aggregate values should be rendered
      expect(response.body).to include("3")  # issues_count
      expect(response.body).to include("2")  # open_issues_count
    end

    it "shows zero for projects with no issues" do
      project_class.create!(name: "Empty Project")

      get "/agg_projects"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Empty Project")
      expect(response.body).to include("0") # issues_count defaults to 0
    end

    it "supports sorting by aggregate column" do
      p1 = project_class.create!(name: "Few Issues")
      p2 = project_class.create!(name: "Many Issues")
      issue_class.create!(title: "A1", status: "open", priority: 1, estimated_hours: 1, agg_project_id: p1.id)
      3.times do |i|
        issue_class.create!(title: "B#{i}", status: "open", priority: 1, estimated_hours: 1, agg_project_id: p2.id)
      end

      get "/agg_projects", params: { sort: "issues_count", direction: "desc" }

      expect(response).to have_http_status(:ok)
      body = response.body
      # Many Issues should appear before Few Issues when sorted desc by count
      many_pos = body.index("Many Issues")
      few_pos = body.index("Few Issues")
      expect(many_pos).to be < few_pos
    end
  end

  describe "GET /agg_projects/:id (show with aggregates)" do
    it "displays aggregate values on the show page" do
      project = project_class.create!(name: "Beta")
      issue_class.create!(title: "Task 1", status: "open", priority: 2, estimated_hours: 3.0, agg_project_id: project.id)
      issue_class.create!(title: "Task 2", status: "open", priority: 4, estimated_hours: 5.0, agg_project_id: project.id)

      get "/agg_projects/#{project.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Beta")
      expect(response.body).to include("2")  # issues_count
    end
  end

  describe "aggregate visibility for restricted roles" do
    it "shows aggregate columns even for viewer role" do
      stub_current_user(role: "viewer")
      project = project_class.create!(name: "Visible")
      issue_class.create!(title: "X", status: "open", priority: 1, estimated_hours: 1, agg_project_id: project.id)

      get "/agg_projects"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Visible")
    end
  end
end
