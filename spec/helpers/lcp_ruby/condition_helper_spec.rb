require "spec_helper"
require "ostruct"

RSpec.describe LcpRuby::ConditionHelper do
  let(:helper) { Object.new.extend(described_class) }
  let(:record) { OpenStruct.new(status: "active", amount: 500) }

  describe "#condition_met?" do
    it "returns true when condition is nil" do
      expect(helper.condition_met?(record, nil)).to be true
    end

    it "returns true for met field-value condition" do
      condition = { "field" => "status", "operator" => "eq", "value" => "active" }
      expect(helper.condition_met?(record, condition)).to be true
    end

    it "returns false for unmet field-value condition" do
      condition = { "field" => "status", "operator" => "eq", "value" => "inactive" }
      expect(helper.condition_met?(record, condition)).to be false
    end

    it "returns true for met service condition" do
      service = Class.new { def self.call(record) = record.status == "active" }
      LcpRuby::ConditionServiceRegistry.register("active_check", service)

      condition = { "service" => "active_check" }
      expect(helper.condition_met?(record, condition)).to be true
    end
  end

  describe "#condition_data_attrs" do
    it "serializes field-value condition to data attributes" do
      condition = { "field" => "status", "operator" => "eq", "value" => "active" }
      attrs = helper.condition_data_attrs(condition, "visible")

      expect(attrs[:"data-lcp-visible-field"]).to eq("status")
      expect(attrs[:"data-lcp-visible-operator"]).to eq("eq")
      expect(attrs[:"data-lcp-visible-value"]).to eq("active")
    end

    it "serializes array values as comma-separated" do
      condition = { "field" => "stage", "operator" => "in", "value" => %w[lead qualified] }
      attrs = helper.condition_data_attrs(condition, "disable")

      expect(attrs[:"data-lcp-disable-value"]).to eq("lead,qualified")
    end

    it "returns empty hash for service conditions" do
      condition = { "service" => "credit_check" }
      attrs = helper.condition_data_attrs(condition, "visible")

      expect(attrs).to be_empty
    end

    it "returns empty hash for non-hash conditions" do
      expect(helper.condition_data_attrs(nil, "visible")).to be_empty
      expect(helper.condition_data_attrs("string", "visible")).to be_empty
    end

    it "handles symbol keys" do
      condition = { field: "status", operator: "eq", value: "active" }
      attrs = helper.condition_data_attrs(condition, "visible")

      expect(attrs[:"data-lcp-visible-field"]).to eq("status")
    end
  end

  describe "#conditional_data" do
    it "builds attrs for visible_when field condition" do
      config = { "visible_when" => { "field" => "status", "operator" => "eq", "value" => "active" } }
      attrs = helper.conditional_data(config)

      expect(attrs[:"data-lcp-visible-field"]).to eq("status")
    end

    it "builds attrs for disable_when field condition" do
      config = { "disable_when" => { "field" => "stage", "operator" => "in", "value" => %w[closed_won] } }
      attrs = helper.conditional_data(config)

      expect(attrs[:"data-lcp-disable-field"]).to eq("stage")
    end

    it "marks service conditions with data-lcp-service-condition" do
      config = { "visible_when" => { "service" => "credit_check" } }
      attrs = helper.conditional_data(config)

      expect(attrs[:"data-lcp-service-condition"]).to eq("visible")
    end

    it "combines both service condition types into comma-separated value" do
      config = {
        "visible_when" => { "service" => "check_a" },
        "disable_when" => { "service" => "check_b" }
      }
      attrs = helper.conditional_data(config)

      expect(attrs[:"data-lcp-service-condition"]).to eq("visible,disable")
    end

    it "returns empty hash when no conditions" do
      config = { "field" => "title" }
      attrs = helper.conditional_data(config)

      expect(attrs).to be_empty
    end
  end

  describe "#service_conditions?" do
    def build_presenter(form_config)
      LcpRuby::Metadata::PresenterDefinition.new(
        name: "test",
        model: "test_model",
        form_config: form_config
      )
    end

    it "returns true when a field has a service condition" do
      presenter = build_presenter({
        "sections" => [
          { "title" => "Details", "fields" => [
            { "field" => "name", "visible_when" => { "service" => "some_check" } }
          ] }
        ]
      })

      expect(helper.service_conditions?(presenter)).to be true
    end

    it "returns true when a section has a service condition" do
      presenter = build_presenter({
        "sections" => [
          { "title" => "Details", "disable_when" => { "service" => "some_check" }, "fields" => [] }
        ]
      })

      expect(helper.service_conditions?(presenter)).to be true
    end

    it "returns false when only field-value conditions are used" do
      presenter = build_presenter({
        "sections" => [
          { "title" => "Details", "fields" => [
            { "field" => "name", "visible_when" => { "field" => "status", "operator" => "eq", "value" => "active" } }
          ] }
        ]
      })

      expect(helper.service_conditions?(presenter)).to be false
    end

    it "returns false when no conditions are present" do
      presenter = build_presenter({
        "sections" => [
          { "title" => "Details", "fields" => [
            { "field" => "name" }
          ] }
        ]
      })

      expect(helper.service_conditions?(presenter)).to be false
    end

    it "returns false for empty sections" do
      presenter = build_presenter({ "sections" => [] })

      expect(helper.service_conditions?(presenter)).to be false
    end
  end
end
