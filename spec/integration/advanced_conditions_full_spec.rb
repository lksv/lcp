require "spec_helper"
require "support/integration_helper"
require "ostruct"

RSpec.describe "Advanced Conditions Full Integration", type: :request do
  before(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("advanced_conditions_test")
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("advanced_conditions_test")
  end

  before(:each) do
    load_integration_metadata!("advanced_conditions_test")

    comment_model.delete_all
    task_model.delete_all
    project_model.delete_all
  end

  let(:project_model) { LcpRuby.registry.model_for("project") }
  let(:task_model) { LcpRuby.registry.model_for("task") }
  let(:comment_model) { LcpRuby.registry.model_for("comment") }

  # ---------------------------------------------------------------
  # Dot-path item_classes on index (belongs_to traversal)
  # ---------------------------------------------------------------
  describe "dot-path item_classes on index" do
    before { stub_current_user(role: "admin") }

    it "applies lcp-row-muted when belongs_to field matches (project.status == archived)" do
      archived_project = project_model.create!(name: "Old Project", status: "archived")
      active_project = project_model.create!(name: "Active Project", status: "active")
      task_model.create!(title: "Archived Task", project: archived_project)
      task_model.create!(title: "Active Task", project: active_project)

      get "/tasks"

      expect(response).to have_http_status(:ok)

      archived_row = response.body.scan(/<tr[^>]*>.*?Archived Task.*?<\/tr>/m).first
      expect(archived_row).to be_present
      expect(archived_row).to include("lcp-row-muted")

      active_row = response.body.scan(/<tr[^>]*>.*?Active Task.*?<\/tr>/m).first
      expect(active_row).to be_present
      expect(active_row).not_to include("lcp-row-muted")
    end

    it "applies compound lcp-row-danger for overdue open tasks (date reference)" do
      project = project_model.create!(name: "Project", status: "active")
      task_model.create!(title: "Overdue Open", project: project, status: "open", due_date: Date.current - 3)
      task_model.create!(title: "Future Open", project: project, status: "open", due_date: Date.current + 3)
      task_model.create!(title: "Overdue Done", project: project, status: "done", due_date: Date.current - 3)

      get "/tasks"

      expect(response).to have_http_status(:ok)

      overdue_row = response.body.scan(/<tr[^>]*>.*?Overdue Open.*?<\/tr>/m).first
      expect(overdue_row).to include("lcp-row-danger")

      future_row = response.body.scan(/<tr[^>]*>.*?Future Open.*?<\/tr>/m).first
      expect(future_row).not_to include("lcp-row-danger")

      done_row = response.body.scan(/<tr[^>]*>.*?Overdue Done.*?<\/tr>/m).first
      expect(done_row).not_to include("lcp-row-danger")
    end

    it "applies lcp-row-success for done tasks" do
      project = project_model.create!(name: "Project", status: "active")
      task_model.create!(title: "Done Task", project: project, status: "done")

      get "/tasks"

      expect(response).to have_http_status(:ok)

      done_row = response.body.scan(/<tr[^>]*>.*?Done Task.*?<\/tr>/m).first
      expect(done_row).to include("lcp-row-success")
    end
  end

  # ---------------------------------------------------------------
  # Dot-path visible_when on show section (belongs_to traversal)
  # ---------------------------------------------------------------
  describe "dot-path visible_when on show section" do
    before { stub_current_user(role: "admin") }

    it "shows 'Tech Details' section when project.industry == technology" do
      project = project_model.create!(name: "Tech Corp", status: "active", industry: "technology")
      task = task_model.create!(title: "Tech Task", project: project)

      get "/tasks/#{task.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Tech Details")
      expect(response.body).to include("Tech Corp")
    end

    it "hides 'Tech Details' section when project.industry != technology" do
      project = project_model.create!(name: "Finance Corp", status: "active", industry: "finance")
      task = task_model.create!(title: "Finance Task", project: project)

      get "/tasks/#{task.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Tech Details")
    end

    it "hides 'Tech Details' section when project.industry is nil" do
      project = project_model.create!(name: "No Industry", status: "active", industry: nil)
      task = task_model.create!(title: "Generic Task", project: project)

      get "/tasks/#{task.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Tech Details")
    end
  end

  # ---------------------------------------------------------------
  # Compound visible_when on show section
  # ---------------------------------------------------------------
  describe "compound visible_when on show section" do
    before { stub_current_user(role: "admin") }

    it "shows 'Urgent Notes' when status != done AND priority >= 80" do
      project = project_model.create!(name: "Project", status: "active")
      task = task_model.create!(title: "Urgent", project: project, status: "open", priority: 90)

      get "/tasks/#{task.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Urgent Notes")
    end

    it "hides 'Urgent Notes' when status == done (even with high priority)" do
      project = project_model.create!(name: "Project", status: "active")
      task = task_model.create!(title: "Done Urgent", project: project, status: "done", priority: 90)

      get "/tasks/#{task.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Urgent Notes")
    end

    it "hides 'Urgent Notes' when priority < 80 (even if open)" do
      project = project_model.create!(name: "Project", status: "active")
      task = task_model.create!(title: "Low Priority", project: project, status: "open", priority: 30)

      get "/tasks/#{task.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Urgent Notes")
    end
  end

  # ---------------------------------------------------------------
  # Collection condition on action visible_when (has_many)
  # ---------------------------------------------------------------
  describe "collection condition on action visible_when" do
    before { stub_current_user(role: "admin") }

    it "shows 'Publish' action when task has approved comments" do
      project = project_model.create!(name: "Project", status: "active")
      task = task_model.create!(title: "Reviewable", project: project, status: "open")
      comment_model.create!(body: "LGTM", approved: true, task: task)

      get "/tasks/#{task.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Publish")
    end

    it "hides 'Publish' action when task has no approved comments" do
      project = project_model.create!(name: "Project", status: "active")
      task = task_model.create!(title: "No Approvals", project: project, status: "open")
      comment_model.create!(body: "Needs work", approved: false, task: task)

      get "/tasks/#{task.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Publish")
    end

    it "hides 'Publish' action when task has no comments at all" do
      project = project_model.create!(name: "Project", status: "active")
      task = task_model.create!(title: "No Comments", project: project, status: "open")

      get "/tasks/#{task.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Publish")
    end

    it "hides 'Publish' action when task is done (compound: status check fails)" do
      project = project_model.create!(name: "Project", status: "active")
      task = task_model.create!(title: "Done With Comments", project: project, status: "done")
      comment_model.create!(body: "LGTM", approved: true, task: task)

      get "/tasks/#{task.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Publish")
    end

    it "shows 'Publish' on index for tasks with approved comments" do
      project = project_model.create!(name: "Project", status: "active")
      task_with = task_model.create!(title: "Has Approval", project: project, status: "open")
      comment_model.create!(body: "Good", approved: true, task: task_with)
      task_without = task_model.create!(title: "No Approval", project: project, status: "open")

      get "/tasks"

      expect(response).to have_http_status(:ok)
      # The task with approved comments should have Publish visible in its actions
      with_row = response.body.scan(/<tr[^>]*>.*?Has Approval.*?<\/tr>/m).first
      without_row = response.body.scan(/<tr[^>]*>.*?No Approval.*?<\/tr>/m).first
      expect(with_row).to include("Publish")
      expect(without_row).not_to include("Publish")
    end
  end

  # ---------------------------------------------------------------
  # Collection condition with real AR has_many (ConditionEvaluator)
  # ---------------------------------------------------------------
  describe "collection condition with real AR has_many" do
    it "evaluates 'any' quantifier on AR has_many relation" do
      project = project_model.create!(name: "Project", status: "active")
      task = task_model.create!(title: "Task", project: project)
      comment_model.create!(body: "Approved", approved: true, task: task)
      comment_model.create!(body: "Pending", approved: false, task: task)

      condition = {
        "collection" => "comments",
        "quantifier" => "any",
        "condition" => { "field" => "approved", "operator" => "eq", "value" => true }
      }
      expect(LcpRuby::ConditionEvaluator.evaluate_any(task, condition)).to be true
    end

    it "evaluates 'all' quantifier on AR has_many relation" do
      project = project_model.create!(name: "Project", status: "active")
      task = task_model.create!(title: "Task", project: project)
      comment_model.create!(body: "Approved 1", approved: true, task: task)
      comment_model.create!(body: "Approved 2", approved: true, task: task)

      condition = {
        "collection" => "comments",
        "quantifier" => "all",
        "condition" => { "field" => "approved", "operator" => "eq", "value" => true }
      }
      expect(LcpRuby::ConditionEvaluator.evaluate_any(task, condition)).to be true
    end

    it "evaluates 'all' quantifier as false when not all match" do
      project = project_model.create!(name: "Project", status: "active")
      task = task_model.create!(title: "Task", project: project)
      comment_model.create!(body: "Approved", approved: true, task: task)
      comment_model.create!(body: "Pending", approved: false, task: task)

      condition = {
        "collection" => "comments",
        "quantifier" => "all",
        "condition" => { "field" => "approved", "operator" => "eq", "value" => true }
      }
      expect(LcpRuby::ConditionEvaluator.evaluate_any(task, condition)).to be false
    end

    it "evaluates 'none' quantifier on AR has_many relation" do
      project = project_model.create!(name: "Project", status: "active")
      task = task_model.create!(title: "Task", project: project)
      comment_model.create!(body: "Pending 1", approved: false, task: task)
      comment_model.create!(body: "Pending 2", approved: false, task: task)

      condition = {
        "collection" => "comments",
        "quantifier" => "none",
        "condition" => { "field" => "approved", "operator" => "eq", "value" => true }
      }
      expect(LcpRuby::ConditionEvaluator.evaluate_any(task, condition)).to be true
    end

    it "evaluates empty has_many with 'any' as false" do
      project = project_model.create!(name: "Project", status: "active")
      task = task_model.create!(title: "No Comments", project: project)

      condition = {
        "collection" => "comments",
        "quantifier" => "any",
        "condition" => { "field" => "approved", "operator" => "eq", "value" => true }
      }
      expect(LcpRuby::ConditionEvaluator.evaluate_any(task, condition)).to be false
    end

    it "evaluates compound condition combining belongs_to dot-path and has_many collection" do
      project = project_model.create!(name: "Tech Corp", status: "active", industry: "technology")
      task = task_model.create!(title: "Task", project: project)
      comment_model.create!(body: "LGTM", approved: true, task: task)

      condition = {
        "all" => [
          { "field" => "project.industry", "operator" => "eq", "value" => "technology" },
          {
            "collection" => "comments",
            "quantifier" => "any",
            "condition" => { "field" => "approved", "operator" => "eq", "value" => true }
          }
        ]
      }
      expect(LcpRuby::ConditionEvaluator.evaluate_any(task, condition)).to be true
    end

    it "returns false when dot-path part of compound fails" do
      project = project_model.create!(name: "Finance Corp", status: "active", industry: "finance")
      task = task_model.create!(title: "Task", project: project)
      comment_model.create!(body: "LGTM", approved: true, task: task)

      condition = {
        "all" => [
          { "field" => "project.industry", "operator" => "eq", "value" => "technology" },
          {
            "collection" => "comments",
            "quantifier" => "any",
            "condition" => { "field" => "approved", "operator" => "eq", "value" => true }
          }
        ]
      }
      expect(LcpRuby::ConditionEvaluator.evaluate_any(task, condition)).to be false
    end
  end

  # ---------------------------------------------------------------
  # Compound record_rules via HTTP
  # ---------------------------------------------------------------
  describe "compound record_rules enforcement" do
    context "as editor (non-exempt role)" do
      before { stub_current_user(role: "editor") }

      it "denies edit for done + high-priority task" do
        project = project_model.create!(name: "Project", status: "active")
        task = task_model.create!(title: "Locked", project: project, status: "done", priority: 90)

        get "/tasks/#{task.id}/edit"

        expect(response).to redirect_to("/tasks")
        follow_redirect!
        expect(response.body).to include("not authorized")
      end

      it "denies destroy for done + high-priority task" do
        project = project_model.create!(name: "Project", status: "active")
        task = task_model.create!(title: "Locked", project: project, status: "done", priority: 90)

        delete "/tasks/#{task.id}"

        expect(response).to redirect_to("/tasks")
        follow_redirect!
        expect(response.body).to include("not authorized")
      end

      it "allows edit for done + low-priority task (compound condition not fully met)" do
        project = project_model.create!(name: "Project", status: "active")
        task = task_model.create!(title: "Editable Done", project: project, status: "done", priority: 30)

        get "/tasks/#{task.id}/edit"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Editable Done")
      end

      it "denies destroy for overdue open task" do
        project = project_model.create!(name: "Project", status: "active")
        task = task_model.create!(title: "Overdue", project: project, status: "open", due_date: Date.current - 5)

        delete "/tasks/#{task.id}"

        expect(response).to redirect_to("/tasks")
        follow_redirect!
        expect(response.body).to include("not authorized")
      end

      it "allows destroy for future open task" do
        project = project_model.create!(name: "Project", status: "active")
        task = task_model.create!(title: "Future", project: project, status: "open", due_date: Date.current + 5)

        delete "/tasks/#{task.id}"

        # Should succeed (redirect to index after destroy)
        expect(response).to redirect_to("/tasks")
        follow_redirect!
        expect(response.body).not_to include("not authorized")
      end

      it "hides edit/destroy buttons on index for locked records" do
        project = project_model.create!(name: "Project", status: "active")
        locked = task_model.create!(title: "Locked Task", project: project, status: "done", priority: 90)
        normal = task_model.create!(title: "Normal Task", project: project, status: "open", priority: 30)

        get "/tasks"

        expect(response).to have_http_status(:ok)

        # Locked task should not have edit link
        expect(response.body).not_to include("href=\"/tasks/#{locked.id}/edit\"")
        # Normal task should have edit link
        expect(response.body).to include("href=\"/tasks/#{normal.id}/edit\"")
      end
    end

    context "as admin (exempt role)" do
      before { stub_current_user(role: "admin") }

      it "allows edit for done + high-priority task" do
        project = project_model.create!(name: "Project", status: "active")
        task = task_model.create!(title: "Admin Edit", project: project, status: "done", priority: 90)

        get "/tasks/#{task.id}/edit"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Admin Edit")
      end

      it "allows destroy for overdue open task" do
        project = project_model.create!(name: "Project", status: "active")
        task = task_model.create!(title: "Admin Delete", project: project, status: "open", due_date: Date.current - 5)

        delete "/tasks/#{task.id}"

        expect(response).to redirect_to("/tasks")
        follow_redirect!
        expect(response.body).not_to include("not authorized")
      end
    end
  end

  # ---------------------------------------------------------------
  # Dot-path field display on show page (belongs_to lookup)
  # ---------------------------------------------------------------
  describe "dot-path field display on show page" do
    before { stub_current_user(role: "admin") }

    it "displays belongs_to field values via dot-path" do
      project = project_model.create!(name: "Cool Project", status: "active", industry: "technology")
      task = task_model.create!(title: "Task", project: project)

      get "/tasks/#{task.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Cool Project")
      expect(response.body).to include("technology")
    end

    it "displays dot-path column values on index" do
      project = project_model.create!(name: "My Project", status: "active")
      task_model.create!(title: "My Task", project: project)

      get "/tasks"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("My Project")
    end
  end
end
