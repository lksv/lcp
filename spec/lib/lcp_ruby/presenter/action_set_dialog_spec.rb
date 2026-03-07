require "spec_helper"
require "ostruct"

RSpec.describe LcpRuby::Presenter::ActionSet, "dialog actions" do
  let(:user) { OpenStruct.new(id: 1, lcp_role: ["admin"], name: "Test") }

  def build_presenter(actions_config)
    LcpRuby::Metadata::PresenterDefinition.new(
      name: "test",
      model: "test_model",
      actions_config: actions_config
    )
  end

  def setup_dialog_page(page_name:, presenter_name:, model_name:, presenter_access: true)
    # Page definition
    page = LcpRuby::Metadata::PageDefinition.new(
      name: page_name,
      model: model_name,
      zones: [LcpRuby::Metadata::ZoneDefinition.new(name: "main", presenter: presenter_name)]
    )
    LcpRuby.loader.page_definitions[page_name] = page

    # Presenter definition for the dialog page
    dialog_presenter = LcpRuby::Metadata::PresenterDefinition.new(
      name: presenter_name,
      model: model_name
    )
    LcpRuby.loader.presenter_definitions[presenter_name] = dialog_presenter

    # Permission definition for the dialog model
    roles = if presenter_access
      { "admin" => { "crud" => ["create"], "presenters" => [presenter_name] } }
    else
      { "admin" => { "crud" => [], "presenters" => [] } }
    end
    perm_def = LcpRuby::Metadata::PermissionDefinition.new(
      model: model_name,
      roles: roles
    )
    LcpRuby.loader.permission_definitions[model_name] = perm_def
  end

  def build_evaluator_for(model_name)
    perm_def = LcpRuby.loader.permission_definition(model_name)
    LcpRuby::Authorization::PermissionEvaluator.new(perm_def, user, model_name)
  end

  before do
    # Set up the host model (the presenter that contains the dialog action)
    host_perm = LcpRuby::Metadata::PermissionDefinition.new(
      model: "test_model",
      roles: { "admin" => { "crud" => %w[index show create update destroy], "presenters" => "all" } }
    )
    LcpRuby.loader.permission_definitions["test_model"] = host_perm
  end

  describe "#filter_actions with type: dialog" do
    it "includes dialog action when user can access the dialog presenter" do
      setup_dialog_page(page_name: "quick_form", presenter_name: "quick_form", model_name: "dialog_model")
      evaluator = build_evaluator_for("test_model")

      presenter = build_presenter({
        "collection" => [
          { "name" => "quick_add", "type" => "dialog", "dialog" => { "page" => "quick_form" } }
        ]
      })
      action_set = described_class.new(presenter, evaluator)

      actions = action_set.collection_actions
      expect(actions.length).to eq(1)
      expect(actions.first["name"]).to eq("quick_add")
    end

    it "excludes dialog action when user cannot access the dialog presenter" do
      setup_dialog_page(page_name: "restricted_form", presenter_name: "restricted_form",
                        model_name: "restricted_model", presenter_access: false)
      evaluator = build_evaluator_for("test_model")

      presenter = build_presenter({
        "collection" => [
          { "name" => "restricted", "type" => "dialog", "dialog" => { "page" => "restricted_form" } }
        ]
      })
      action_set = described_class.new(presenter, evaluator)

      actions = action_set.collection_actions
      expect(actions).to be_empty
    end

    it "excludes dialog action when dialog config is missing" do
      evaluator = build_evaluator_for("test_model")

      presenter = build_presenter({
        "collection" => [
          { "name" => "broken", "type" => "dialog" }
        ]
      })
      action_set = described_class.new(presenter, evaluator)

      actions = action_set.collection_actions
      expect(actions).to be_empty
    end

    it "excludes dialog action when page name is missing" do
      evaluator = build_evaluator_for("test_model")

      presenter = build_presenter({
        "collection" => [
          { "name" => "broken", "type" => "dialog", "dialog" => {} }
        ]
      })
      action_set = described_class.new(presenter, evaluator)

      actions = action_set.collection_actions
      expect(actions).to be_empty
    end

    it "raises MetadataError for unknown page in non-production" do
      evaluator = build_evaluator_for("test_model")

      presenter = build_presenter({
        "collection" => [
          { "name" => "bad_ref", "type" => "dialog", "dialog" => { "page" => "nonexistent_page" } }
        ]
      })
      action_set = described_class.new(presenter, evaluator)

      expect { action_set.collection_actions }.to raise_error(LcpRuby::MetadataError)
    end

    it "works for single actions" do
      setup_dialog_page(page_name: "edit_form", presenter_name: "edit_form", model_name: "edit_model")
      evaluator = build_evaluator_for("test_model")

      presenter = build_presenter({
        "single" => [
          { "name" => "quick_edit", "type" => "dialog",
            "dialog" => { "page" => "edit_form", "record" => "current" } }
        ]
      })
      action_set = described_class.new(presenter, evaluator)

      actions = action_set.single_actions
      expect(actions.length).to eq(1)
      expect(actions.first["name"]).to eq("quick_edit")
    end

    it "works for batch actions" do
      setup_dialog_page(page_name: "bulk_form", presenter_name: "bulk_form", model_name: "bulk_model")
      evaluator = build_evaluator_for("test_model")

      presenter = build_presenter({
        "batch" => [
          { "name" => "bulk_update", "type" => "dialog", "dialog" => { "page" => "bulk_form" } }
        ]
      })
      action_set = described_class.new(presenter, evaluator)

      actions = action_set.batch_actions
      expect(actions.length).to eq(1)
      expect(actions.first["name"]).to eq("bulk_update")
    end

    it "performs cross-model authorization (dialog model differs from host model)" do
      # Host model is test_model, dialog model is other_model
      setup_dialog_page(page_name: "cross_form", presenter_name: "cross_form", model_name: "other_model")
      evaluator = build_evaluator_for("test_model")

      presenter = build_presenter({
        "collection" => [
          { "name" => "cross_add", "type" => "dialog", "dialog" => { "page" => "cross_form" } }
        ]
      })
      action_set = described_class.new(presenter, evaluator)

      actions = action_set.collection_actions
      expect(actions.length).to eq(1)
    end

    it "caches authorization result for the same page" do
      setup_dialog_page(page_name: "cached_form", presenter_name: "cached_form", model_name: "cached_model")
      evaluator = build_evaluator_for("test_model")

      presenter = build_presenter({
        "single" => [
          { "name" => "action1", "type" => "dialog", "dialog" => { "page" => "cached_form" } },
          { "name" => "action2", "type" => "dialog", "dialog" => { "page" => "cached_form" } }
        ]
      })
      action_set = described_class.new(presenter, evaluator)

      # Should only create one PermissionEvaluator for both actions
      expect(LcpRuby::Authorization::PermissionEvaluator).to receive(:new).once.and_call_original

      actions = action_set.single_actions
      expect(actions.length).to eq(2)
    end
  end

  describe "#single_actions confirm with styled confirmation" do
    let(:permission_evaluator) do
      evaluator = double("PermissionEvaluator")
      allow(evaluator).to receive(:can?).and_return(true)
      allow(evaluator).to receive(:can_execute_action?).and_return(true)
      allow(evaluator).to receive(:can_for_record?).and_return(true)
      allow(evaluator).to receive(:roles).and_return(["admin"])
      evaluator
    end

    it "passes through styled confirmation hash with title_key, message_key, style" do
      presenter = build_presenter({
        "single" => [
          { "name" => "archive", "type" => "custom",
            "confirm" => { "title_key" => "confirm.archive_title", "message_key" => "confirm.archive_msg", "style" => "danger" } }
        ]
      })
      action_set = described_class.new(presenter, permission_evaluator)

      actions = action_set.single_actions
      confirm = actions.first["confirm"]
      expect(confirm).to be_a(Hash)
      expect(confirm["title_key"]).to eq("confirm.archive_title")
      expect(confirm["message_key"]).to eq("confirm.archive_msg")
      expect(confirm["style"]).to eq("danger")
    end

    it "passes through styled confirmation with only title_key" do
      presenter = build_presenter({
        "single" => [
          { "name" => "archive", "type" => "custom",
            "confirm" => { "title_key" => "confirm.title" } }
        ]
      })
      action_set = described_class.new(presenter, permission_evaluator)

      actions = action_set.single_actions
      confirm = actions.first["confirm"]
      expect(confirm).to be_a(Hash)
      expect(confirm["title_key"]).to eq("confirm.title")
    end

    it "passes through styled confirmation with only style" do
      presenter = build_presenter({
        "single" => [
          { "name" => "delete_all", "type" => "custom",
            "confirm" => { "style" => "danger" } }
        ]
      })
      action_set = described_class.new(presenter, permission_evaluator)

      actions = action_set.single_actions
      confirm = actions.first["confirm"]
      expect(confirm).to be_a(Hash)
      expect(confirm["style"]).to eq("danger")
    end

    it "passes through page-based confirmation hash" do
      presenter = build_presenter({
        "single" => [
          { "name" => "complex_confirm", "type" => "custom",
            "confirm" => { "page" => "confirm_dialog_page" } }
        ]
      })
      action_set = described_class.new(presenter, permission_evaluator)

      actions = action_set.single_actions
      confirm = actions.first["confirm"]
      expect(confirm).to be_a(Hash)
      expect(confirm["page"]).to eq("confirm_dialog_page")
    end

    it "coerces unknown hash shape to boolean true" do
      presenter = build_presenter({
        "single" => [
          { "name" => "weird", "type" => "custom",
            "confirm" => { "unknown_key" => "value" } }
        ]
      })
      action_set = described_class.new(presenter, permission_evaluator)

      actions = action_set.single_actions
      expect(actions.first["confirm"]).to be true
    end
  end
end
