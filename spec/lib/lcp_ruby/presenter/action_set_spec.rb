require "spec_helper"
require "ostruct"

RSpec.describe LcpRuby::Presenter::ActionSet do
  let(:record) { OpenStruct.new(status: "active", stage: "qualified", value: 500.0) }

  let(:permission_evaluator) do
    evaluator = double("PermissionEvaluator")
    allow(evaluator).to receive(:can?).and_return(true)
    allow(evaluator).to receive(:can_execute_action?).and_return(true)
    allow(evaluator).to receive(:can_for_record?).and_return(true)
    allow(evaluator).to receive(:roles).and_return([ "admin" ])
    evaluator
  end

  def build_presenter(actions_config)
    LcpRuby::Metadata::PresenterDefinition.new(
      name: "test",
      model: "test_model",
      actions_config: actions_config
    )
  end

  describe "#single_actions with disable_when" do
    it "marks action as disabled when condition is met" do
      presenter = build_presenter({
        "single" => [
          { "name" => "close", "type" => "custom",
            "disable_when" => { "field" => "stage", "operator" => "eq", "value" => "qualified" } }
        ]
      })
      action_set = described_class.new(presenter, permission_evaluator)

      actions = action_set.single_actions(record)
      expect(actions.first["_disabled"]).to be true
    end

    it "does not mark action as disabled when condition is not met" do
      presenter = build_presenter({
        "single" => [
          { "name" => "close", "type" => "custom",
            "disable_when" => { "field" => "stage", "operator" => "eq", "value" => "lead" } }
        ]
      })
      action_set = described_class.new(presenter, permission_evaluator)

      actions = action_set.single_actions(record)
      expect(actions.first["_disabled"]).to be false
    end

    it "does not mark action as disabled when no disable_when" do
      presenter = build_presenter({
        "single" => [
          { "name" => "show", "type" => "built_in" }
        ]
      })
      action_set = described_class.new(presenter, permission_evaluator)

      actions = action_set.single_actions(record)
      expect(actions.first["_disabled"]).to be false
    end

    it "handles blank operator for disable_when" do
      record_with_blank = OpenStruct.new(value: "")
      presenter = build_presenter({
        "single" => [
          { "name" => "close", "type" => "custom",
            "disable_when" => { "field" => "value", "operator" => "blank" } }
        ]
      })
      action_set = described_class.new(presenter, permission_evaluator)

      actions = action_set.single_actions(record_with_blank)
      expect(actions.first["_disabled"]).to be true
    end
  end

  describe "#single_actions with visible_when using evaluate_any" do
    it "filters out actions based on field-value conditions" do
      presenter = build_presenter({
        "single" => [
          { "name" => "close", "type" => "custom",
            "visible_when" => { "field" => "stage", "operator" => "not_in", "value" => %w[closed_won closed_lost] } }
        ]
      })
      action_set = described_class.new(presenter, permission_evaluator)

      actions = action_set.single_actions(record)
      expect(actions.length).to eq(1)
    end

    it "hides action when visible_when condition not met" do
      closed_record = OpenStruct.new(stage: "closed_won")
      presenter = build_presenter({
        "single" => [
          { "name" => "close", "type" => "custom",
            "visible_when" => { "field" => "stage", "operator" => "not_in", "value" => %w[closed_won closed_lost] } }
        ]
      })
      action_set = described_class.new(presenter, permission_evaluator)

      actions = action_set.single_actions(closed_record)
      expect(actions).to be_empty
    end
  end

  describe "#single_actions with combined visible_when and disable_when" do
    it "hides action when visible_when is false (disable_when irrelevant)" do
      closed_record = OpenStruct.new(stage: "closed_won", value: "")
      presenter = build_presenter({
        "single" => [
          { "name" => "close", "type" => "custom",
            "visible_when" => { "field" => "stage", "operator" => "not_in", "value" => %w[closed_won closed_lost] },
            "disable_when" => { "field" => "value", "operator" => "blank" } }
        ]
      })
      action_set = described_class.new(presenter, permission_evaluator)

      actions = action_set.single_actions(closed_record)
      expect(actions).to be_empty
    end

    it "shows but disables action when visible and disable condition met" do
      presenter = build_presenter({
        "single" => [
          { "name" => "close", "type" => "custom",
            "visible_when" => { "field" => "stage", "operator" => "not_in", "value" => %w[closed_won closed_lost] },
            "disable_when" => { "field" => "stage", "operator" => "eq", "value" => "qualified" } }
        ]
      })
      action_set = described_class.new(presenter, permission_evaluator)

      actions = action_set.single_actions(record)
      expect(actions.length).to eq(1)
      expect(actions.first["_disabled"]).to be true
    end
  end

  describe "#single_actions with service conditions" do
    before { LcpRuby::ConditionServiceRegistry.clear! }

    it "evaluates service-based visible_when" do
      service = Class.new { def self.call(record) = record.stage != "closed_won" }
      LcpRuby::ConditionServiceRegistry.register("open_check", service)

      presenter = build_presenter({
        "single" => [
          { "name" => "close", "type" => "custom",
            "visible_when" => { "service" => "open_check" } }
        ]
      })
      action_set = described_class.new(presenter, permission_evaluator)

      expect(action_set.single_actions(record).length).to eq(1)

      closed_record = OpenStruct.new(stage: "closed_won")
      expect(action_set.single_actions(closed_record)).to be_empty
    end

    it "evaluates service-based disable_when" do
      service = Class.new { def self.call(record) = record.value.to_f <= 0 }
      LcpRuby::ConditionServiceRegistry.register("no_value_check", service)

      presenter = build_presenter({
        "single" => [
          { "name" => "close", "type" => "custom",
            "disable_when" => { "service" => "no_value_check" } }
        ]
      })
      action_set = described_class.new(presenter, permission_evaluator)

      actions = action_set.single_actions(record)
      expect(actions.first["_disabled"]).to be false

      zero_record = OpenStruct.new(value: 0)
      actions = action_set.single_actions(zero_record)
      expect(actions.first["_disabled"]).to be true
    end
  end

  describe "#single_actions with record_rules (action_permitted_for_record?)" do
    it "hides built-in edit action when can_for_record? returns false" do
      allow(permission_evaluator).to receive(:can_for_record?).with("edit", record).and_return(false)

      presenter = build_presenter({
        "single" => [
          { "name" => "edit", "type" => "built_in" }
        ]
      })
      action_set = described_class.new(presenter, permission_evaluator)

      actions = action_set.single_actions(record)
      expect(actions).to be_empty
    end

    it "hides built-in destroy action when can_for_record? returns false" do
      allow(permission_evaluator).to receive(:can_for_record?).with("destroy", record).and_return(false)

      presenter = build_presenter({
        "single" => [
          { "name" => "destroy", "type" => "built_in" }
        ]
      })
      action_set = described_class.new(presenter, permission_evaluator)

      actions = action_set.single_actions(record)
      expect(actions).to be_empty
    end

    it "does not hide built-in show action even when record rule denies it" do
      # show resolves to "show", which is not in RECORD_RULE_ACTIONS
      presenter = build_presenter({
        "single" => [
          { "name" => "show", "type" => "built_in" }
        ]
      })
      action_set = described_class.new(presenter, permission_evaluator)

      # can_for_record? should not be called for show
      actions = action_set.single_actions(record)
      expect(actions.length).to eq(1)
      expect(actions.first["name"]).to eq("show")
    end

    it "does not affect custom actions" do
      presenter = build_presenter({
        "single" => [
          { "name" => "archive", "type" => "custom" }
        ]
      })
      action_set = described_class.new(presenter, permission_evaluator)

      # can_for_record? should not be called for custom actions
      actions = action_set.single_actions(record)
      expect(actions.length).to eq(1)
      expect(actions.first["name"]).to eq("archive")
    end

    it "applies both record_rules and visible_when (AND semantics)" do
      allow(permission_evaluator).to receive(:can_for_record?).with("edit", record).and_return(true)

      presenter = build_presenter({
        "single" => [
          { "name" => "edit", "type" => "built_in",
            "visible_when" => { "field" => "status", "operator" => "eq", "value" => "inactive" } }
        ]
      })
      action_set = described_class.new(presenter, permission_evaluator)

      # Record rules pass but visible_when fails
      actions = action_set.single_actions(record)
      expect(actions).to be_empty
    end

    it "filters only denied actions in a mixed list" do
      allow(permission_evaluator).to receive(:can_for_record?).with("edit", record).and_return(false)
      allow(permission_evaluator).to receive(:can_for_record?).with("destroy", record).and_return(true)

      presenter = build_presenter({
        "single" => [
          { "name" => "edit", "type" => "built_in" },
          { "name" => "destroy", "type" => "built_in" },
          { "name" => "show", "type" => "built_in" }
        ]
      })
      action_set = described_class.new(presenter, permission_evaluator)

      actions = action_set.single_actions(record)
      action_names = actions.map { |a| a["name"] }
      expect(action_names).to eq(%w[destroy show])
    end
  end

  describe "#single_actions without record" do
    it "returns actions without disable check" do
      presenter = build_presenter({
        "single" => [
          { "name" => "show", "type" => "built_in" },
          { "name" => "close", "type" => "custom",
            "disable_when" => { "field" => "value", "operator" => "blank" } }
        ]
      })
      action_set = described_class.new(presenter, permission_evaluator)

      actions = action_set.single_actions
      expect(actions.length).to eq(2)
      expect(actions.first).not_to have_key("_disabled")
    end
  end

  describe "#single_actions confirm per role" do
    it "keeps confirm: true as-is (backward compatible)" do
      presenter = build_presenter({
        "single" => [
          { "name" => "archive", "type" => "custom", "confirm" => true }
        ]
      })
      action_set = described_class.new(presenter, permission_evaluator)

      actions = action_set.single_actions
      expect(actions.first["confirm"]).to be true
    end

    it "keeps confirm: false as-is (backward compatible)" do
      presenter = build_presenter({
        "single" => [
          { "name" => "archive", "type" => "custom", "confirm" => false }
        ]
      })
      action_set = described_class.new(presenter, permission_evaluator)

      actions = action_set.single_actions
      expect(actions.first["confirm"]).to be false
    end

    it "keeps confirm: nil as-is when absent" do
      presenter = build_presenter({
        "single" => [
          { "name" => "archive", "type" => "custom" }
        ]
      })
      action_set = described_class.new(presenter, permission_evaluator)

      actions = action_set.single_actions
      expect(actions.first["confirm"]).to be_nil
    end

    context "confirm with except" do
      it "skips confirm when user role is in except list" do
        # admin is in except list, so confirm should be false
        presenter = build_presenter({
          "single" => [
            { "name" => "archive", "type" => "custom",
              "confirm" => { "except" => [ "admin" ] } }
          ]
        })
        action_set = described_class.new(presenter, permission_evaluator)

        actions = action_set.single_actions
        expect(actions.first["confirm"]).to be false
      end

      it "shows confirm when user role is NOT in except list" do
        viewer_evaluator = double("PermissionEvaluator")
        allow(viewer_evaluator).to receive(:can?).and_return(true)
        allow(viewer_evaluator).to receive(:can_execute_action?).and_return(true)
        allow(viewer_evaluator).to receive(:roles).and_return([ "viewer" ])

        presenter = build_presenter({
          "single" => [
            { "name" => "archive", "type" => "custom",
              "confirm" => { "except" => [ "admin" ] } }
          ]
        })
        action_set = described_class.new(presenter, viewer_evaluator)

        actions = action_set.single_actions
        expect(actions.first["confirm"]).to be true
      end
    end

    context "confirm with only" do
      it "shows confirm when user role is in only list" do
        viewer_evaluator = double("PermissionEvaluator")
        allow(viewer_evaluator).to receive(:can?).and_return(true)
        allow(viewer_evaluator).to receive(:can_execute_action?).and_return(true)
        allow(viewer_evaluator).to receive(:roles).and_return([ "viewer" ])

        presenter = build_presenter({
          "single" => [
            { "name" => "force_delete", "type" => "custom",
              "confirm" => { "only" => [ "viewer", "sales_rep" ] } }
          ]
        })
        action_set = described_class.new(presenter, viewer_evaluator)

        actions = action_set.single_actions
        expect(actions.first["confirm"]).to be true
      end

      it "skips confirm when user role is NOT in only list" do
        # admin is not in only list
        presenter = build_presenter({
          "single" => [
            { "name" => "force_delete", "type" => "custom",
              "confirm" => { "only" => [ "viewer", "sales_rep" ] } }
          ]
        })
        action_set = described_class.new(presenter, permission_evaluator)

        actions = action_set.single_actions
        expect(actions.first["confirm"]).to be false
      end
    end

    context "confirm with multiple roles" do
      it "skips confirm when any user role is in except list" do
        multi_evaluator = double("PermissionEvaluator")
        allow(multi_evaluator).to receive(:can?).and_return(true)
        allow(multi_evaluator).to receive(:can_execute_action?).and_return(true)
        allow(multi_evaluator).to receive(:roles).and_return([ "viewer", "admin" ])

        presenter = build_presenter({
          "single" => [
            { "name" => "archive", "type" => "custom",
              "confirm" => { "except" => [ "admin" ] } }
          ]
        })
        action_set = described_class.new(presenter, multi_evaluator)

        actions = action_set.single_actions
        expect(actions.first["confirm"]).to be false
      end

      it "shows confirm when any user role is in only list" do
        multi_evaluator = double("PermissionEvaluator")
        allow(multi_evaluator).to receive(:can?).and_return(true)
        allow(multi_evaluator).to receive(:can_execute_action?).and_return(true)
        allow(multi_evaluator).to receive(:roles).and_return([ "admin", "viewer" ])

        presenter = build_presenter({
          "single" => [
            { "name" => "force_delete", "type" => "custom",
              "confirm" => { "only" => [ "viewer" ] } }
          ]
        })
        action_set = described_class.new(presenter, multi_evaluator)

        actions = action_set.single_actions
        expect(actions.first["confirm"]).to be true
      end
    end
  end
end
