require "spec_helper"
require "support/integration_helper"

RSpec.describe "Redirect After CRUD", type: :request do
  before(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("redirect_after_test")
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("redirect_after_test")
  end

  before(:each) do
    load_integration_metadata!("redirect_after_test")
    stub_current_user(role: "admin")
    LcpRuby.registry.model_for("redirect_task").delete_all
  end

  let(:task_model) { LcpRuby.registry.model_for("redirect_task") }

  describe "default redirect behavior (no redirect_after config)" do
    it "redirects to show after create" do
      post "/tasks-default", params: { record: { title: "New Task" } }

      created = task_model.last
      expect(response).to redirect_to("/tasks-default/#{created.id}")
    end

    it "redirects to show after update" do
      task = task_model.create!(title: "Old Title")

      patch "/tasks-default/#{task.id}", params: { record: { title: "Updated" } }

      expect(response).to redirect_to("/tasks-default/#{task.id}")
    end

    it "redirects to index after destroy" do
      task = task_model.create!(title: "To Delete")

      delete "/tasks-default/#{task.id}"

      expect(response).to redirect_to("/tasks-default")
    end
  end

  describe "redirect_after: index" do
    it "redirects to index after create" do
      post "/tasks-redirect-index", params: { record: { title: "New Task" } }

      expect(response).to redirect_to("/tasks-redirect-index")
    end

    it "redirects to index after update" do
      task = task_model.create!(title: "Old Title")

      patch "/tasks-redirect-index/#{task.id}", params: { record: { title: "Updated" } }

      expect(response).to redirect_to("/tasks-redirect-index")
    end

    it "redirects to index after destroy (always index)" do
      task = task_model.create!(title: "To Delete")

      delete "/tasks-redirect-index/#{task.id}"

      expect(response).to redirect_to("/tasks-redirect-index")
    end
  end

  describe "redirect_after: edit" do
    it "redirects to edit after create" do
      post "/tasks-redirect-edit", params: { record: { title: "New Task" } }

      created = task_model.last
      expect(response).to redirect_to("/tasks-redirect-edit/#{created.id}/edit")
    end

    it "redirects to edit after update" do
      task = task_model.create!(title: "Old Title")

      patch "/tasks-redirect-edit/#{task.id}", params: { record: { title: "Updated" } }

      expect(response).to redirect_to("/tasks-redirect-edit/#{task.id}/edit")
    end
  end

  describe "flash messages" do
    it "includes i18n flash message after create" do
      post "/tasks-default", params: { record: { title: "Flash Test" } }

      expect(flash[:notice]).to eq("Task was successfully created.")
    end

    it "includes i18n flash message after update" do
      task = task_model.create!(title: "Old Title")

      patch "/tasks-default/#{task.id}", params: { record: { title: "Updated" } }

      expect(flash[:notice]).to eq("Task was successfully updated.")
    end

    it "includes i18n flash message after destroy" do
      task = task_model.create!(title: "To Delete")

      delete "/tasks-default/#{task.id}"

      expect(flash[:notice]).to eq("Task was successfully deleted.")
    end
  end
end
