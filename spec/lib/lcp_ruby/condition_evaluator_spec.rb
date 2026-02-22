require "spec_helper"
require "ostruct"

RSpec.describe LcpRuby::ConditionEvaluator do
  let(:record) do
    OpenStruct.new(
      status: "active",
      stage: "qualified",
      amount: 500.0,
      name: "Test Deal",
      email: "user@example.com",
      notes: nil,
      value: ""
    )
  end

  describe ".evaluate" do
    it "raises ArgumentError when condition is nil" do
      expect { described_class.evaluate(record, nil) }.to raise_error(ArgumentError, /must be a Hash/)
    end

    it "raises ArgumentError when condition is not a Hash" do
      expect { described_class.evaluate(record, "string") }.to raise_error(ArgumentError, /must be a Hash/)
    end

    it "raises ConditionError when field key is missing" do
      expect {
        described_class.evaluate(record, { "operator" => "eq", "value" => "x" })
      }.to raise_error(LcpRuby::ConditionError, /missing required 'field' key/)
    end

    it "raises ConditionError when record does not respond to field" do
      expect {
        described_class.evaluate(record, { "field" => "nonexistent", "operator" => "eq", "value" => "x" })
      }.to raise_error(LcpRuby::ConditionError, /does not respond to field 'nonexistent'/)
    end

    it "raises ConditionError when operator key is missing" do
      expect {
        described_class.evaluate(record, { "field" => "status", "value" => "active" })
      }.to raise_error(LcpRuby::ConditionError, /missing required 'operator' key/)
    end

    it "evaluates eq operator" do
      expect(described_class.evaluate(record, { "field" => "status", "operator" => "eq", "value" => "active" })).to be true
      expect(described_class.evaluate(record, { "field" => "status", "operator" => "eq", "value" => "inactive" })).to be false
    end

    it "evaluates not_eq operator" do
      expect(described_class.evaluate(record, { "field" => "status", "operator" => "not_eq", "value" => "inactive" })).to be true
      expect(described_class.evaluate(record, { "field" => "status", "operator" => "not_eq", "value" => "active" })).to be false
    end

    it "evaluates neq alias" do
      expect(described_class.evaluate(record, { "field" => "status", "operator" => "neq", "value" => "inactive" })).to be true
    end

    it "evaluates in operator" do
      expect(described_class.evaluate(record, { "field" => "stage", "operator" => "in", "value" => %w[qualified lead] })).to be true
      expect(described_class.evaluate(record, { "field" => "stage", "operator" => "in", "value" => %w[lead closed_won] })).to be false
    end

    it "evaluates not_in operator" do
      expect(described_class.evaluate(record, { "field" => "stage", "operator" => "not_in", "value" => %w[lead closed_won] })).to be true
      expect(described_class.evaluate(record, { "field" => "stage", "operator" => "not_in", "value" => %w[qualified lead] })).to be false
    end

    it "evaluates gt operator" do
      expect(described_class.evaluate(record, { "field" => "amount", "operator" => "gt", "value" => 100 })).to be true
      expect(described_class.evaluate(record, { "field" => "amount", "operator" => "gt", "value" => 500 })).to be false
    end

    it "evaluates gte operator" do
      expect(described_class.evaluate(record, { "field" => "amount", "operator" => "gte", "value" => 500 })).to be true
      expect(described_class.evaluate(record, { "field" => "amount", "operator" => "gte", "value" => 501 })).to be false
    end

    it "evaluates lt operator" do
      expect(described_class.evaluate(record, { "field" => "amount", "operator" => "lt", "value" => 1000 })).to be true
      expect(described_class.evaluate(record, { "field" => "amount", "operator" => "lt", "value" => 500 })).to be false
    end

    it "evaluates lte operator" do
      expect(described_class.evaluate(record, { "field" => "amount", "operator" => "lte", "value" => 500 })).to be true
      expect(described_class.evaluate(record, { "field" => "amount", "operator" => "lte", "value" => 499 })).to be false
    end

    it "evaluates present operator" do
      expect(described_class.evaluate(record, { "field" => "name", "operator" => "present" })).to be true
      expect(described_class.evaluate(record, { "field" => "notes", "operator" => "present" })).to be false
    end

    it "evaluates blank operator" do
      expect(described_class.evaluate(record, { "field" => "notes", "operator" => "blank" })).to be true
      expect(described_class.evaluate(record, { "field" => "name", "operator" => "blank" })).to be false
    end

    it "evaluates matches operator" do
      expect(described_class.evaluate(record, { "field" => "email", "operator" => "matches", "value" => "^[^@]+@[^@]+$" })).to be true
      expect(described_class.evaluate(record, { "field" => "email", "operator" => "matches", "value" => "^\\d+$" })).to be false
    end

    it "evaluates not_matches operator" do
      expect(described_class.evaluate(record, { "field" => "email", "operator" => "not_matches", "value" => "^\\d+$" })).to be true
      expect(described_class.evaluate(record, { "field" => "email", "operator" => "not_matches", "value" => "^[^@]+@[^@]+$" })).to be false
    end

    it "returns false for matches with non-string value" do
      expect(described_class.evaluate(record, { "field" => "email", "operator" => "matches", "value" => 123 })).to be false
    end

    it "returns false for matches with invalid regex pattern" do
      expect(described_class.evaluate(record, { "field" => "email", "operator" => "matches", "value" => "[invalid" })).to be false
    end

    it "returns true for not_matches with invalid regex pattern" do
      expect(described_class.evaluate(record, { "field" => "email", "operator" => "not_matches", "value" => "[invalid" })).to be true
    end

    it "handles symbol keys" do
      expect(described_class.evaluate(record, { field: "status", operator: "eq", value: "active" })).to be true
    end

    it "raises ConditionError for unknown operator" do
      expect {
        described_class.evaluate(record, { "field" => "status", "operator" => "unknown", "value" => "active" })
      }.to raise_error(LcpRuby::ConditionError, /unknown condition operator 'unknown'/)
    end
  end

  describe ".safe_regexp" do
    it "returns a Regexp with timeout for valid patterns" do
      re = described_class.safe_regexp("^test$")
      expect(re).to be_a(Regexp)
      expect("test").to match(re)
    end

    it "returns a never-matching Regexp for invalid patterns" do
      re = described_class.safe_regexp("[invalid")
      expect(re).to be_a(Regexp)
      expect("anything").not_to match(re)
    end
  end

  describe ".condition_type" do
    it "returns :field_value for field conditions" do
      expect(described_class.condition_type({ "field" => "status", "operator" => "eq", "value" => "active" })).to eq(:field_value)
    end

    it "returns :service for service conditions" do
      expect(described_class.condition_type({ "service" => "credit_check" })).to eq(:service)
    end

    it "returns nil for non-hash values" do
      expect(described_class.condition_type("string")).to be_nil
      expect(described_class.condition_type(nil)).to be_nil
    end

    it "returns nil for hash without field or service keys" do
      expect(described_class.condition_type({ "other" => "value" })).to be_nil
    end

    it "handles symbol keys" do
      expect(described_class.condition_type({ field: "status" })).to eq(:field_value)
      expect(described_class.condition_type({ service: "check" })).to eq(:service)
    end
  end

  describe ".client_evaluable?" do
    it "returns true for field-value conditions" do
      expect(described_class.client_evaluable?({ "field" => "status", "operator" => "eq", "value" => "active" })).to be true
    end

    it "returns false for service conditions" do
      expect(described_class.client_evaluable?({ "service" => "credit_check" })).to be false
    end

    it "returns false for nil" do
      expect(described_class.client_evaluable?(nil)).to be false
    end
  end

  describe ".evaluate_service" do
    before do
      LcpRuby::ConditionServiceRegistry.clear!
    end

    it "raises ArgumentError when condition is nil" do
      expect { described_class.evaluate_service(record, nil) }.to raise_error(ArgumentError, /must be a Hash/)
    end

    it "raises ConditionError when service is not registered" do
      expect {
        described_class.evaluate_service(record, { "service" => "nonexistent" })
      }.to raise_error(LcpRuby::ConditionError, /not registered/)
    end

    it "raises ConditionError when service key is missing" do
      expect {
        described_class.evaluate_service(record, { "other" => "value" })
      }.to raise_error(LcpRuby::ConditionError, /missing required 'service' key/)
    end

    it "evaluates registered service" do
      service = Class.new { def self.call(record) = record.status == "active" }
      LcpRuby::ConditionServiceRegistry.register("status_check", service)

      expect(described_class.evaluate_service(record, { "service" => "status_check" })).to be true
    end

    it "returns false for service returning falsy" do
      service = Class.new { def self.call(record) = false }
      LcpRuby::ConditionServiceRegistry.register("always_false", service)

      expect(described_class.evaluate_service(record, { "service" => "always_false" })).to be false
    end
  end

  describe ".evaluate_any" do
    before do
      LcpRuby::ConditionServiceRegistry.clear!
    end

    it "raises ArgumentError for nil condition" do
      expect { described_class.evaluate_any(record, nil) }.to raise_error(ArgumentError, /must be a Hash/)
    end

    it "routes field-value conditions to evaluate" do
      expect(described_class.evaluate_any(record, { "field" => "status", "operator" => "eq", "value" => "active" })).to be true
    end

    it "routes service conditions to evaluate_service" do
      service = Class.new { def self.call(record) = record.amount > 100 }
      LcpRuby::ConditionServiceRegistry.register("amount_check", service)

      expect(described_class.evaluate_any(record, { "service" => "amount_check" })).to be true
    end

    it "raises ConditionError for unknown condition type" do
      expect {
        described_class.evaluate_any(record, { "other" => "value" })
      }.to raise_error(LcpRuby::ConditionError, /must contain a 'field' or 'service' key/)
    end
  end
end
