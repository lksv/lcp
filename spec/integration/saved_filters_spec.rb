require "spec_helper"
require "support/integration_helper"

RSpec.describe "Saved Filters Integration", type: :request do
  before(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("saved_filters")
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("saved_filters")
  end

  before(:each) do
    load_integration_metadata!("saved_filters")
    saved_filter_model.delete_all
    task_model.delete_all
  end

  let(:task_model) { LcpRuby.registry.model_for("filtered_task") }
  let(:saved_filter_model) { LcpRuby.registry.model_for("saved_filter") }

  describe "Saved filters CRUD API" do
    before { stub_current_user(role: "admin") }

    it "creates a saved filter via POST" do
      condition_tree = {
        "combinator" => "and",
        "children" => [
          { "field" => "status", "operator" => "eq", "value" => "open" }
        ]
      }

      post "/filtered-tasks/saved-filters", params: {
        saved_filter: {
          name: "Open Tasks",
          condition_tree: condition_tree.to_json,
          visibility: "personal"
        }
      }

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["name"]).to eq("Open Tasks")
      expect(json["visibility"]).to eq("personal")
      expect(json["is_owner"]).to be true
    end

    it "lists visible saved filters via GET" do
      saved_filter_model.create!(
        name: "My Filter",
        target_presenter: "filtered-tasks",
        condition_tree: { "combinator" => "and", "children" => [] },
        visibility: "personal",
        owner_id: 1
      )

      get "/filtered-tasks/saved-filters"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.size).to eq(1)
      expect(json.first["name"]).to eq("My Filter")
    end

    it "updates a saved filter via PATCH" do
      filter = saved_filter_model.create!(
        name: "Old Name",
        target_presenter: "filtered-tasks",
        condition_tree: { "combinator" => "and", "children" => [] },
        visibility: "personal",
        owner_id: 1
      )

      patch "/filtered-tasks/saved-filters/#{filter.id}", params: {
        saved_filter: { name: "New Name" }
      }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["name"]).to eq("New Name")
    end

    it "deletes a saved filter via DELETE" do
      filter = saved_filter_model.create!(
        name: "To Delete",
        target_presenter: "filtered-tasks",
        condition_tree: { "combinator" => "and", "children" => [] },
        visibility: "personal",
        owner_id: 1
      )

      expect {
        delete "/filtered-tasks/saved-filters/#{filter.id}"
      }.to change { saved_filter_model.count }.by(-1)

      expect(response).to have_http_status(:ok)
    end

    it "prevents non-admin from modifying another user's personal filter" do
      stub_current_user(role: "user", id: 2)

      filter = saved_filter_model.create!(
        name: "Other User Filter",
        target_presenter: "filtered-tasks",
        condition_tree: { "combinator" => "and", "children" => [] },
        visibility: "personal",
        owner_id: 999
      )

      delete "/filtered-tasks/saved-filters/#{filter.id}", headers: { "Accept" => "application/json" }
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "Applying saved filter on index" do
    before { stub_current_user(role: "admin") }

    it "filters records when ?saved_filter=<id> is present" do
      task_model.create!(title: "Open Bug", status: "open")
      task_model.create!(title: "Closed Feature", status: "closed")

      filter = saved_filter_model.create!(
        name: "Open Only",
        target_presenter: "filtered-tasks",
        condition_tree: {
          "combinator" => "and",
          "children" => [
            { "field" => "status", "operator" => "eq", "value" => "open" }
          ]
        },
        visibility: "personal",
        owner_id: 1
      )

      get "/filtered-tasks", params: { saved_filter: filter.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Open Bug")
      expect(response.body).not_to include("Closed Feature")
    end

    it "returns all records when saved filter ID is invalid" do
      task_model.create!(title: "Task A", status: "open")
      task_model.create!(title: "Task B", status: "closed")

      get "/filtered-tasks", params: { saved_filter: 99999 }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Task A")
      expect(response.body).to include("Task B")
    end
  end

  describe "Visibility scoping" do
    before { stub_current_user(role: "admin") }

    it "shows personal filters only to the owner" do
      saved_filter_model.create!(
        name: "My Filter", target_presenter: "filtered-tasks",
        condition_tree: { "combinator" => "and", "children" => [] },
        visibility: "personal", owner_id: 1
      )
      saved_filter_model.create!(
        name: "Other Filter", target_presenter: "filtered-tasks",
        condition_tree: { "combinator" => "and", "children" => [] },
        visibility: "personal", owner_id: 999
      )

      get "/filtered-tasks/saved-filters"

      json = JSON.parse(response.body)
      names = json.map { |f| f["name"] }
      expect(names).to include("My Filter")
      expect(names).not_to include("Other Filter")
    end

    it "shows global filters to everyone" do
      saved_filter_model.create!(
        name: "Global Filter", target_presenter: "filtered-tasks",
        condition_tree: { "combinator" => "and", "children" => [] },
        visibility: "global", owner_id: 999
      )

      get "/filtered-tasks/saved-filters"

      json = JSON.parse(response.body)
      expect(json.map { |f| f["name"] }).to include("Global Filter")
    end

    it "shows role-matched filters" do
      saved_filter_model.create!(
        name: "Admin Filter", target_presenter: "filtered-tasks",
        condition_tree: { "combinator" => "and", "children" => [] },
        visibility: "role", target_role: "admin", owner_id: 999
      )
      saved_filter_model.create!(
        name: "Manager Filter", target_presenter: "filtered-tasks",
        condition_tree: { "combinator" => "and", "children" => [] },
        visibility: "role", target_role: "manager", owner_id: 999
      )

      get "/filtered-tasks/saved-filters"

      json = JSON.parse(response.body)
      names = json.map { |f| f["name"] }
      expect(names).to include("Admin Filter")
      expect(names).not_to include("Manager Filter")
    end
  end

  describe "Default filter auto-application" do
    before { stub_current_user(role: "admin") }

    it "auto-applies the default filter when no filter params are present" do
      task_model.create!(title: "Open Task", status: "open")
      task_model.create!(title: "Closed Task", status: "closed")

      saved_filter_model.create!(
        name: "Default Open",
        target_presenter: "filtered-tasks",
        condition_tree: {
          "combinator" => "and",
          "children" => [
            { "field" => "status", "operator" => "eq", "value" => "open" }
          ]
        },
        visibility: "personal",
        owner_id: 1,
        default_filter: true
      )

      get "/filtered-tasks"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Open Task")
      expect(response.body).not_to include("Closed Task")
    end

    it "does not auto-apply default when explicit filter params are present" do
      task_model.create!(title: "Open Task", status: "open")
      task_model.create!(title: "Closed Task", status: "closed")

      saved_filter_model.create!(
        name: "Default Open",
        target_presenter: "filtered-tasks",
        condition_tree: {
          "combinator" => "and",
          "children" => [
            { "field" => "status", "operator" => "eq", "value" => "open" }
          ]
        },
        visibility: "personal",
        owner_id: 1,
        default_filter: true
      )

      # Predefined filter "all" is an explicit filter, so default should not apply
      get "/filtered-tasks", params: { filter: "all" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Open Task")
      expect(response.body).to include("Closed Task")
    end
  end

  describe "Stale field handling" do
    before { stub_current_user(role: "admin") }

    it "gracefully handles a saved filter with a nonexistent field" do
      task_model.create!(title: "Test Task", status: "open")

      filter = saved_filter_model.create!(
        name: "Stale Filter",
        target_presenter: "filtered-tasks",
        condition_tree: {
          "combinator" => "and",
          "children" => [
            { "field" => "nonexistent_field", "operator" => "eq", "value" => "x" },
            { "field" => "status", "operator" => "eq", "value" => "open" }
          ]
        },
        visibility: "personal",
        owner_id: 1
      )

      get "/filtered-tasks", params: { saved_filter: filter.id }

      expect(response).to have_http_status(:ok)
      # The valid part of the filter (status=open) still applies
      expect(response.body).to include("Test Task")
    end
  end

  describe "Dialog-based saved filter creation" do
    before { stub_current_user(role: "admin") }

    it "creates a saved filter via POST with _dialog=1 and returns dialog success" do
      condition_tree = {
        "combinator" => "and",
        "children" => [
          { "field" => "status", "operator" => "eq", "value" => "open" }
        ]
      }

      post "/filtered-tasks/saved-filters", params: {
        _dialog: "1",
        saved_filter: {
          name: "Dialog Filter",
          condition_tree: condition_tree.to_json,
          visibility: "personal"
        }
      }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("data-lcp-dialog-action")
      expect(saved_filter_model.last.name).to eq("Dialog Filter")
      expect(saved_filter_model.last.condition_tree).to be_present
    end

    it "returns JSON errors when dialog validation fails" do
      post "/filtered-tasks/saved-filters", params: {
        _dialog: "1",
        saved_filter: {
          name: "",
          condition_tree: { "combinator" => "and", "children" => [] }.to_json,
          visibility: "personal"
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["errors"]).to be_present
    end

    it "returns JSON error when limit is reached via dialog" do
      50.times do |i|
        saved_filter_model.create!(
          name: "Filter #{i}",
          target_presenter: "filtered-tasks",
          condition_tree: { "combinator" => "and", "children" => [] },
          visibility: "personal",
          owner_id: 1
        )
      end

      post "/filtered-tasks/saved-filters", params: {
        _dialog: "1",
        saved_filter: {
          name: "Over Limit",
          condition_tree: { "combinator" => "and", "children" => [] }.to_json,
          visibility: "personal"
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["error"]).to be_present
    end
  end

  describe "Saved filter limit enforcement" do
    before { stub_current_user(role: "admin") }

    it "enforces personal filter limit" do
      # Default limit is 50 per user; create enough to hit limit
      # The limit is configurable via presenter config; we'll test with the default
      50.times do |i|
        saved_filter_model.create!(
          name: "Filter #{i}",
          target_presenter: "filtered-tasks",
          condition_tree: { "combinator" => "and", "children" => [] },
          visibility: "personal",
          owner_id: 1
        )
      end

      post "/filtered-tasks/saved-filters", params: {
        saved_filter: {
          name: "One Too Many",
          condition_tree: { "combinator" => "and", "children" => [] }.to_json,
          visibility: "personal"
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["error"]).to be_present
    end
  end
end
