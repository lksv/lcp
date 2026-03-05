require "spec_helper"
require "support/integration_helper"

RSpec.describe "Item Classes (Row Styling)", type: :request do
  before(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("item_classes")
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("item_classes")
  end

  before(:each) do
    load_integration_metadata!("item_classes")
    stub_current_user(role: "admin")

    task_class = LcpRuby.registry.model_for("task")
    task_class.delete_all
    task_class.create!(title: "Open task", status: "open", priority: "low")
    task_class.create!(title: "Done task", status: "done", priority: "low")
    task_class.create!(title: "High priority", status: "open", priority: "high")
    task_class.create!(title: "Done and high", status: "done", priority: "high")
  end

  describe "GET /tasks (table layout)" do
    it "applies lcp-row-muted and lcp-row-strikethrough to done tasks" do
      get "/tasks"
      expect(response).to have_http_status(:ok)

      # Done task should have muted + strikethrough classes
      expect(response.body).to include("lcp-row-muted lcp-row-strikethrough")
    end

    it "applies lcp-row-bold to high priority tasks" do
      get "/tasks"
      expect(response).to have_http_status(:ok)

      expect(response.body).to include("lcp-row-bold")
    end

    it "accumulates multiple matching classes on a single row" do
      get "/tasks"
      expect(response).to have_http_status(:ok)

      # "Done and high" task should have both rule sets
      # The row should contain both sets of classes
      doc = response.body
      # Find the row containing "Done and high"
      done_high_row = doc.scan(/<tr[^>]*>.*?Done and high.*?<\/tr>/m).first
      expect(done_high_row).to be_present
      expect(done_high_row).to include("lcp-row-muted")
      expect(done_high_row).to include("lcp-row-strikethrough")
      expect(done_high_row).to include("lcp-row-bold")
    end

    it "does not apply styling classes to non-matching rows" do
      get "/tasks"
      expect(response).to have_http_status(:ok)

      # "Open task" (status: open, priority: low) should not have any item_classes
      open_row = response.body.scan(/<tr[^>]*>.*?Open task.*?<\/tr>/m).first
      expect(open_row).to be_present
      expect(open_row).not_to include("lcp-row-muted")
      expect(open_row).not_to include("lcp-row-bold")
      expect(open_row).not_to include("lcp-row-strikethrough")
    end
  end
end
