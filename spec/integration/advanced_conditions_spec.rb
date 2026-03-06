require "spec_helper"
require "support/integration_helper"
require "ostruct"

RSpec.describe "Advanced Conditions Integration", type: :request do
  before(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("crm")
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("crm")
  end

  before(:each) do
    load_integration_metadata!("crm")
    LcpRuby.registry.model_for("deal").delete_all
    LcpRuby.registry.model_for("contact").delete_all
    LcpRuby.registry.model_for("company").delete_all
  end

  let(:company_model) { LcpRuby.registry.model_for("company") }
  let(:deal_model) { LcpRuby.registry.model_for("deal") }

  describe "compound record_rules" do
    it "compound AND condition denies update when both criteria match" do
      company = company_model.create!(name: "Big Corp", industry: "finance")
      deal = deal_model.create!(title: "Big Deal", stage: "closed_won", value: 50_000, company: company)

      perm_def = LcpRuby.loader.permission_definition("deal")
      original_rules = perm_def.record_rules
      perm_def.instance_variable_set(:@record_rules, [
        {
          "name" => "compound_lock",
          "condition" => {
            "all" => [
              { "field" => "stage", "operator" => "in", "value" => %w[closed_won closed_lost] },
              { "field" => "value", "operator" => "gt", "value" => 10_000 }
            ]
          },
          "effect" => { "deny_crud" => %w[update destroy], "except_roles" => %w[admin] }
        }
      ])

      user = OpenStruct.new(id: 2, lcp_role: [ "sales_rep" ])
      evaluator = LcpRuby::Authorization::PermissionEvaluator.new(perm_def, user, "deal")
      expect(evaluator.can_for_record?(:update, deal)).to be false

      admin_user = OpenStruct.new(id: 1, lcp_role: [ "admin" ])
      admin_evaluator = LcpRuby::Authorization::PermissionEvaluator.new(perm_def, admin_user, "deal")
      expect(admin_evaluator.can_for_record?(:update, deal)).to be true

      perm_def.instance_variable_set(:@record_rules, original_rules)
    end
  end

  describe "dot-path conditions with real AR models" do
    it "evaluates dot-path field on associated record" do
      company = company_model.create!(name: "Tech Corp", industry: "technology")
      deal = deal_model.create!(title: "Tech Deal", stage: "lead", value: 1000, company: company)

      condition = { "field" => "company.industry", "operator" => "eq", "value" => "technology" }
      result = LcpRuby::ConditionEvaluator.evaluate_any(deal, condition)
      expect(result).to be true

      condition_mismatch = { "field" => "company.industry", "operator" => "eq", "value" => "finance" }
      result_mismatch = LcpRuby::ConditionEvaluator.evaluate_any(deal, condition_mismatch)
      expect(result_mismatch).to be false
    end
  end

  describe "dynamic date comparison" do
    it "evaluates date: today reference" do
      record = OpenStruct.new(due_date: Date.current - 1, status: "open")
      condition = {
        "all" => [
          { "field" => "status", "operator" => "not_eq", "value" => "done" },
          { "field" => "due_date", "operator" => "lt", "value" => { "date" => "today" } }
        ]
      }
      expect(LcpRuby::ConditionEvaluator.evaluate_any(record, condition)).to be true
    end

    it "returns false when date is in the future" do
      record = OpenStruct.new(due_date: Date.current + 1, status: "open")
      condition = { "field" => "due_date", "operator" => "lt", "value" => { "date" => "today" } }
      expect(LcpRuby::ConditionEvaluator.evaluate_any(record, condition)).to be false
    end
  end

  describe "current_user owner-only record_rules" do
    it "denies update when author_id != current_user.id" do
      record = OpenStruct.new(author_id: 42, status: "active")
      user = OpenStruct.new(id: 99, lcp_role: [ "editor" ])

      condition = {
        "not" => { "field" => "author_id", "operator" => "eq", "value" => { "current_user" => "id" } }
      }
      result = LcpRuby::ConditionEvaluator.evaluate_any(record, condition, context: { current_user: user })
      expect(result).to be true
    end

    it "allows update when author_id == current_user.id" do
      record = OpenStruct.new(author_id: 42, status: "active")
      user = OpenStruct.new(id: 42, lcp_role: [ "editor" ])

      condition = {
        "not" => { "field" => "author_id", "operator" => "eq", "value" => { "current_user" => "id" } }
      }
      result = LcpRuby::ConditionEvaluator.evaluate_any(record, condition, context: { current_user: user })
      expect(result).to be false
    end
  end

  describe "collection-based action gating" do
    it "gates on has_many collection with quantifier" do
      approval1 = OpenStruct.new(status: "approved")
      approval2 = OpenStruct.new(status: "pending")
      record = OpenStruct.new(stage: "review", approvals: [ approval1, approval2 ])

      condition = {
        "all" => [
          { "field" => "stage", "operator" => "eq", "value" => "review" },
          {
            "collection" => "approvals",
            "quantifier" => "any",
            "condition" => { "field" => "status", "operator" => "eq", "value" => "approved" }
          }
        ]
      }
      expect(LcpRuby::ConditionEvaluator.evaluate_any(record, condition)).to be true
    end
  end

  describe "DSL condition builder integration" do
    it "builds a condition that the evaluator can process" do
      condition = LcpRuby::Dsl::ConditionBuilder.build do
        all do
          field(:status).eq("active")
          field(:amount).gt(field_ref: "budget_limit")
          not_condition do
            field(:stage).eq("closed")
          end
        end
      end

      record = OpenStruct.new(status: "active", amount: 500, budget_limit: 300, stage: "open")
      expect(LcpRuby::ConditionEvaluator.evaluate_any(record, condition)).to be true

      record2 = OpenStruct.new(status: "active", amount: 100, budget_limit: 300, stage: "open")
      expect(LcpRuby::ConditionEvaluator.evaluate_any(record2, condition)).to be false
    end
  end

  describe "GET /deals (index with real request)" do
    before { stub_current_user(role: "admin") }

    it "renders index page with advanced conditions available" do
      company = company_model.create!(name: "Test Corp", industry: "technology")
      deal_model.create!(title: "Active Deal", stage: "lead", value: 1000, company: company)

      get "/deals"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Active Deal")
    end
  end
end
