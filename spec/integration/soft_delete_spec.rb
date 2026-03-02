require "spec_helper"
require "support/integration_helper"

RSpec.describe "Soft Delete Integration", type: :request do
  before(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("soft_delete")
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("soft_delete")
  end

  before(:each) do
    load_integration_metadata!("soft_delete")
    stub_current_user(role: "admin")
    LcpRuby.registry.model_for("sd_task").delete_all
    LcpRuby.registry.model_for("sd_project").delete_all
    LcpRuby.registry.model_for("sd_note").delete_all
  end

  let(:project_model) { LcpRuby.registry.model_for("sd_project") }
  let(:task_model) { LcpRuby.registry.model_for("sd_task") }
  let(:note_model) { LcpRuby.registry.model_for("sd_note") }

  describe "DELETE /projects/:id (soft delete)" do
    it "soft deletes the project instead of hard deleting" do
      project = project_model.create!(title: "My Project")

      delete "/projects/#{project.id}"

      expect(response).to have_http_status(:redirect)
      follow_redirect!
      expect(response.body).to include("archived")

      # Record still exists in DB but is discarded
      expect(project_model.kept.where(id: project.id).count).to eq(0)
      expect(project_model.where(id: project.id).count).to eq(1)

      project.reload
      expect(project.discarded_at).to be_present
    end

    it "cascade discards child tasks" do
      project = project_model.create!(title: "My Project")
      task = task_model.create!(title: "My Task", sd_project_id: project.id)

      delete "/projects/#{project.id}"

      task.reload
      expect(task.discarded?).to be true
      expect(task["discarded_by_type"]).to eq(project.class.name)
      expect(task["discarded_by_id"]).to eq(project.id)
    end
  end

  describe "GET /projects (index with default kept scope)" do
    it "excludes discarded projects from index" do
      kept = project_model.create!(title: "Kept Project")
      discarded = project_model.create!(title: "Discarded Project")
      discarded.discard!

      get "/projects"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Kept Project")
      expect(response.body).not_to include("Discarded Project")
    end
  end

  describe "GET /projects/:id for discarded record" do
    it "raises RecordNotFound for discarded record on the active presenter" do
      project = project_model.create!(title: "Will Be Discarded")
      project.discard!

      # set_record scopes to kept, so discarded records are not found
      get "/projects/#{project.id}"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /projects-archive (archive presenter with scope: discarded)" do
    it "shows only discarded projects" do
      kept = project_model.create!(title: "Kept Project")
      discarded = project_model.create!(title: "Discarded Project")
      discarded.discard!

      get "/projects-archive"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Discarded Project")
      expect(response.body).not_to include("Kept Project")
    end
  end

  describe "POST /projects-archive/:id/restore" do
    it "restores a discarded project" do
      project = project_model.create!(title: "Archived Project")
      project.discard!

      post "/projects-archive/#{project.id}/restore"

      expect(response).to have_http_status(:redirect)
      follow_redirect!
      expect(response.body).to include("restored")

      project.reload
      expect(project.discarded_at).to be_nil
      expect(project.kept?).to be true
    end

    it "cascade restores child tasks that were cascade-discarded" do
      project = project_model.create!(title: "Project")
      task_cascade = task_model.create!(title: "Cascade Task", sd_project_id: project.id)
      task_manual = task_model.create!(title: "Manual Task", sd_project_id: project.id)

      # Manually discard one task first
      task_manual.discard!
      # Discard the project (cascades to task_cascade only)
      project.discard!

      # Restore via controller
      post "/projects-archive/#{project.id}/restore"

      task_cascade.reload
      task_manual.reload
      expect(task_cascade.kept?).to be true
      expect(task_manual.discarded?).to be true
    end
  end

  describe "DELETE /projects-archive/:id/permanently_destroy" do
    it "permanently deletes the record" do
      project = project_model.create!(title: "To Permanently Delete")
      project.discard!

      delete "/projects-archive/#{project.id}/permanently_destroy"

      expect(response).to have_http_status(:redirect)
      follow_redirect!
      expect(response.body).to include("permanently deleted")

      expect(project_model.unscoped.where(id: project.id).count).to eq(0)
    end
  end

  describe "permission checks" do
    it "denies restore to viewer role" do
      stub_current_user(role: "viewer")
      project = project_model.create!(title: "Project")
      project.discard!

      post "/projects-archive/#{project.id}/restore"

      expect(response).to have_http_status(:redirect)
      follow_redirect!
      expect(response.body).to include("not authorized")
    end

    it "denies permanently_destroy to viewer role" do
      stub_current_user(role: "viewer")
      project = project_model.create!(title: "Project")
      project.discard!

      delete "/projects-archive/#{project.id}/permanently_destroy"

      expect(response).to have_http_status(:redirect)
      follow_redirect!
      expect(response.body).to include("not authorized")
    end
  end

  describe "non-soft-deletable model (note) still hard-deletes" do
    it "hard deletes the note" do
      note = note_model.create!(title: "My Note")

      delete "/notes/#{note.id}"

      expect(response).to have_http_status(:redirect)
      expect(note_model.where(id: note.id).count).to eq(0)
    end
  end
end
