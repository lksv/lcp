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
      value: "",
      budget_limit: 1000.0,
      author_id: 42
    )
  end

  describe ".evaluate" do
    it "raises ArgumentError when condition is nil" do
      expect { described_class.evaluate_any(record, nil) }.to raise_error(ArgumentError, /must be a Hash/)
    end

    it "raises ArgumentError when condition is not a Hash" do
      expect { described_class.evaluate_any(record, "string") }.to raise_error(ArgumentError, /must be a Hash/)
    end

    it "raises ConditionError when field key is missing" do
      expect {
        described_class.evaluate_any(record, { "operator" => "eq", "value" => "x" })
      }.to raise_error(LcpRuby::ConditionError, /must contain/)
    end

    it "raises ConditionError when record does not respond to field" do
      expect {
        described_class.evaluate_any(record, { "field" => "nonexistent", "operator" => "eq", "value" => "x" })
      }.to raise_error(LcpRuby::ConditionError, /does not respond to field 'nonexistent'/)
    end

    it "raises ConditionError when operator key is missing" do
      expect {
        described_class.evaluate_any(record, { "field" => "status", "value" => "active" })
      }.to raise_error(LcpRuby::ConditionError, /missing required 'operator' key/)
    end

    it "evaluates eq operator" do
      expect(described_class.evaluate_any(record, { "field" => "status", "operator" => "eq", "value" => "active" })).to be true
      expect(described_class.evaluate_any(record, { "field" => "status", "operator" => "eq", "value" => "inactive" })).to be false
    end

    it "evaluates not_eq operator" do
      expect(described_class.evaluate_any(record, { "field" => "status", "operator" => "not_eq", "value" => "inactive" })).to be true
      expect(described_class.evaluate_any(record, { "field" => "status", "operator" => "not_eq", "value" => "active" })).to be false
    end

    it "evaluates neq alias" do
      expect(described_class.evaluate_any(record, { "field" => "status", "operator" => "neq", "value" => "inactive" })).to be true
    end

    it "evaluates in operator" do
      expect(described_class.evaluate_any(record, { "field" => "stage", "operator" => "in", "value" => %w[qualified lead] })).to be true
      expect(described_class.evaluate_any(record, { "field" => "stage", "operator" => "in", "value" => %w[lead closed_won] })).to be false
    end

    it "evaluates not_in operator" do
      expect(described_class.evaluate_any(record, { "field" => "stage", "operator" => "not_in", "value" => %w[lead closed_won] })).to be true
      expect(described_class.evaluate_any(record, { "field" => "stage", "operator" => "not_in", "value" => %w[qualified lead] })).to be false
    end

    it "evaluates gt operator" do
      expect(described_class.evaluate_any(record, { "field" => "amount", "operator" => "gt", "value" => 100 })).to be true
      expect(described_class.evaluate_any(record, { "field" => "amount", "operator" => "gt", "value" => 500 })).to be false
    end

    it "evaluates gte operator" do
      expect(described_class.evaluate_any(record, { "field" => "amount", "operator" => "gte", "value" => 500 })).to be true
      expect(described_class.evaluate_any(record, { "field" => "amount", "operator" => "gte", "value" => 501 })).to be false
    end

    it "evaluates lt operator" do
      expect(described_class.evaluate_any(record, { "field" => "amount", "operator" => "lt", "value" => 1000 })).to be true
      expect(described_class.evaluate_any(record, { "field" => "amount", "operator" => "lt", "value" => 500 })).to be false
    end

    it "evaluates lte operator" do
      expect(described_class.evaluate_any(record, { "field" => "amount", "operator" => "lte", "value" => 500 })).to be true
      expect(described_class.evaluate_any(record, { "field" => "amount", "operator" => "lte", "value" => 499 })).to be false
    end

    it "evaluates present operator" do
      expect(described_class.evaluate_any(record, { "field" => "name", "operator" => "present" })).to be true
      expect(described_class.evaluate_any(record, { "field" => "notes", "operator" => "present" })).to be false
    end

    it "evaluates blank operator" do
      expect(described_class.evaluate_any(record, { "field" => "notes", "operator" => "blank" })).to be true
      expect(described_class.evaluate_any(record, { "field" => "name", "operator" => "blank" })).to be false
    end

    it "evaluates starts_with operator" do
      expect(described_class.evaluate_any(record, { "field" => "name", "operator" => "starts_with", "value" => "Test" })).to be true
      expect(described_class.evaluate_any(record, { "field" => "name", "operator" => "starts_with", "value" => "Other" })).to be false
    end

    it "evaluates starts_with with nil field" do
      expect(described_class.evaluate_any(record, { "field" => "notes", "operator" => "starts_with", "value" => "x" })).to be false
    end

    it "evaluates ends_with operator" do
      expect(described_class.evaluate_any(record, { "field" => "name", "operator" => "ends_with", "value" => "Deal" })).to be true
      expect(described_class.evaluate_any(record, { "field" => "name", "operator" => "ends_with", "value" => "Other" })).to be false
    end

    it "evaluates ends_with with nil field" do
      expect(described_class.evaluate_any(record, { "field" => "notes", "operator" => "ends_with", "value" => "x" })).to be false
    end

    it "evaluates contains operator (case-insensitive)" do
      expect(described_class.evaluate_any(record, { "field" => "name", "operator" => "contains", "value" => "test" })).to be true
      expect(described_class.evaluate_any(record, { "field" => "name", "operator" => "contains", "value" => "TEST" })).to be true
      expect(described_class.evaluate_any(record, { "field" => "name", "operator" => "contains", "value" => "xyz" })).to be false
    end

    it "evaluates contains with nil field" do
      expect(described_class.evaluate_any(record, { "field" => "notes", "operator" => "contains", "value" => "x" })).to be false
    end

    it "evaluates matches operator" do
      expect(described_class.evaluate_any(record, { "field" => "email", "operator" => "matches", "value" => "^[^@]+@[^@]+$" })).to be true
      expect(described_class.evaluate_any(record, { "field" => "email", "operator" => "matches", "value" => "^\\d+$" })).to be false
    end

    it "evaluates not_matches operator" do
      expect(described_class.evaluate_any(record, { "field" => "email", "operator" => "not_matches", "value" => "^\\d+$" })).to be true
      expect(described_class.evaluate_any(record, { "field" => "email", "operator" => "not_matches", "value" => "^[^@]+@[^@]+$" })).to be false
    end

    it "returns false for matches with non-string value" do
      expect(described_class.evaluate_any(record, { "field" => "email", "operator" => "matches", "value" => 123 })).to be false
    end

    it "returns false for matches with invalid regex pattern" do
      expect(described_class.evaluate_any(record, { "field" => "email", "operator" => "matches", "value" => "[invalid" })).to be false
    end

    it "returns true for not_matches with invalid regex pattern" do
      expect(described_class.evaluate_any(record, { "field" => "email", "operator" => "not_matches", "value" => "[invalid" })).to be true
    end

    it "handles symbol keys" do
      expect(described_class.evaluate_any(record, { field: "status", operator: "eq", value: "active" })).to be true
    end

    it "raises ConditionError for unknown operator" do
      expect {
        described_class.evaluate_any(record, { "field" => "status", "operator" => "unknown", "value" => "active" })
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

    it "returns :compound for all/any/not conditions" do
      expect(described_class.condition_type({ "all" => [] })).to eq(:compound)
      expect(described_class.condition_type({ "any" => [] })).to eq(:compound)
      expect(described_class.condition_type({ "not" => {} })).to eq(:compound)
    end

    it "returns :collection for collection conditions" do
      expect(described_class.condition_type({ "collection" => "items" })).to eq(:collection)
    end

    it "returns nil for non-hash values" do
      expect(described_class.condition_type("string")).to be_nil
      expect(described_class.condition_type(nil)).to be_nil
    end

    it "returns nil for hash without recognized keys" do
      expect(described_class.condition_type({ "other" => "value" })).to be_nil
    end

    it "handles symbol keys" do
      expect(described_class.condition_type({ field: "status" })).to eq(:field_value)
      expect(described_class.condition_type({ service: "check" })).to eq(:service)
    end
  end

  describe ".client_evaluable?" do
    it "returns true for simple field-value conditions" do
      expect(described_class.client_evaluable?({ "field" => "status", "operator" => "eq", "value" => "active" })).to be true
    end

    it "returns false for service conditions" do
      expect(described_class.client_evaluable?({ "service" => "credit_check" })).to be false
    end

    it "returns false for nil" do
      expect(described_class.client_evaluable?(nil)).to be false
    end

    it "returns false for compound conditions" do
      expect(described_class.client_evaluable?({ "all" => [] })).to be false
    end

    it "returns false for collection conditions" do
      expect(described_class.client_evaluable?({ "collection" => "items" })).to be false
    end

    it "returns false when value is a dynamic reference" do
      expect(described_class.client_evaluable?({ "field" => "amount", "operator" => "gt", "value" => { "field_ref" => "budget" } })).to be false
    end

    it "returns false for dot-path fields" do
      expect(described_class.client_evaluable?({ "field" => "company.name", "operator" => "eq", "value" => "x" })).to be false
    end
  end

  describe ".evaluate_service" do
    before do
      LcpRuby::ConditionServiceRegistry.clear!
    end

    it "raises ArgumentError when condition is nil" do
      expect { described_class.evaluate_any(record, nil) }.to raise_error(ArgumentError, /must be a Hash/)
    end

    it "raises ConditionError when service is not registered" do
      expect {
        described_class.evaluate_any(record, { "service" => "nonexistent" })
      }.to raise_error(LcpRuby::ConditionError, /not registered/)
    end

    it "raises ConditionError when no recognized key is present" do
      expect {
        described_class.evaluate_any(record, { "other" => "value" })
      }.to raise_error(LcpRuby::ConditionError, /must contain/)
    end

    it "evaluates registered service" do
      service = Class.new { def self.call(record) = record.status == "active" }
      LcpRuby::ConditionServiceRegistry.register("status_check", service)

      expect(described_class.evaluate_any(record, { "service" => "status_check" })).to be true
    end

    it "returns false for service returning falsy" do
      service = Class.new { def self.call(record) = false }
      LcpRuby::ConditionServiceRegistry.register("always_false", service)

      expect(described_class.evaluate_any(record, { "service" => "always_false" })).to be false
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
      }.to raise_error(LcpRuby::ConditionError, /must contain/)
    end
  end

  describe "compound conditions (all/any/not)" do
    it "evaluates 'all' — all children must be true" do
      condition = {
        "all" => [
          { "field" => "status", "operator" => "eq", "value" => "active" },
          { "field" => "amount", "operator" => "gt", "value" => 100 }
        ]
      }
      expect(described_class.evaluate_any(record, condition)).to be true
    end

    it "returns false for 'all' when one child fails" do
      condition = {
        "all" => [
          { "field" => "status", "operator" => "eq", "value" => "active" },
          { "field" => "amount", "operator" => "gt", "value" => 1000 }
        ]
      }
      expect(described_class.evaluate_any(record, condition)).to be false
    end

    it "evaluates 'any' — at least one child must be true" do
      condition = {
        "any" => [
          { "field" => "status", "operator" => "eq", "value" => "inactive" },
          { "field" => "amount", "operator" => "gt", "value" => 100 }
        ]
      }
      expect(described_class.evaluate_any(record, condition)).to be true
    end

    it "returns false for 'any' when all children fail" do
      condition = {
        "any" => [
          { "field" => "status", "operator" => "eq", "value" => "inactive" },
          { "field" => "amount", "operator" => "gt", "value" => 1000 }
        ]
      }
      expect(described_class.evaluate_any(record, condition)).to be false
    end

    it "evaluates 'not' — negates the child condition" do
      condition = {
        "not" => { "field" => "status", "operator" => "eq", "value" => "inactive" }
      }
      expect(described_class.evaluate_any(record, condition)).to be true
    end

    it "returns false for 'not' when child is true" do
      condition = {
        "not" => { "field" => "status", "operator" => "eq", "value" => "active" }
      }
      expect(described_class.evaluate_any(record, condition)).to be false
    end

    it "handles nested compound conditions" do
      condition = {
        "all" => [
          { "field" => "status", "operator" => "eq", "value" => "active" },
          {
            "any" => [
              { "field" => "amount", "operator" => "gt", "value" => 1000 },
              { "field" => "stage", "operator" => "eq", "value" => "qualified" }
            ]
          }
        ]
      }
      expect(described_class.evaluate_any(record, condition)).to be true
    end

    it "returns true for empty 'all' (vacuous truth)" do
      expect(described_class.evaluate_any(record, { "all" => [] })).to be true
    end

    it "returns false for empty 'any'" do
      expect(described_class.evaluate_any(record, { "any" => [] })).to be false
    end

    it "raises on excessive nesting depth" do
      # Build a deeply nested condition
      condition = { "field" => "status", "operator" => "eq", "value" => "active" }
      (LcpRuby::ConditionEvaluator::MAX_NESTING_DEPTH + 1).times do
        condition = { "not" => condition }
      end

      expect {
        described_class.evaluate_any(record, condition)
      }.to raise_error(LcpRuby::ConditionError, /nesting depth exceeded/)
    end

    it "mixes compound with service conditions" do
      LcpRuby::ConditionServiceRegistry.clear!
      service = Class.new { def self.call(record) = record.amount > 100 }
      LcpRuby::ConditionServiceRegistry.register("amount_check", service)

      condition = {
        "all" => [
          { "field" => "status", "operator" => "eq", "value" => "active" },
          { "service" => "amount_check" }
        ]
      }
      expect(described_class.evaluate_any(record, condition)).to be true
    end

    it "handles symbol keys in compound conditions" do
      condition = {
        all: [
          { field: "status", operator: "eq", value: "active" },
          { field: "amount", operator: "gt", value: 100 }
        ]
      }
      expect(described_class.evaluate_any(record, condition)).to be true
    end
  end

  describe "dot-path field traversal" do
    let(:country) { OpenStruct.new(code: "CZ", name: "Czech Republic") }
    let(:company) { OpenStruct.new(name: "Acme", country: country, industry: "finance") }
    let(:record_with_assoc) { OpenStruct.new(status: "active", company: company, amount: 500.0) }

    it "resolves a single-level dot-path" do
      condition = { "field" => "company.name", "operator" => "eq", "value" => "Acme" }
      expect(described_class.evaluate_any(record_with_assoc, condition)).to be true
    end

    it "resolves a multi-level dot-path" do
      condition = { "field" => "company.country.code", "operator" => "eq", "value" => "CZ" }
      expect(described_class.evaluate_any(record_with_assoc, condition)).to be true
    end

    it "raises ConditionError for unknown intermediate segment" do
      condition = { "field" => "unknown.name", "operator" => "eq", "value" => "x" }
      expect {
        described_class.evaluate_any(record_with_assoc, condition)
      }.to raise_error(LcpRuby::ConditionError, /does not respond to 'unknown'/)
    end

    it "raises ConditionError for nil intermediate value" do
      record_nil_company = OpenStruct.new(status: "active", company: nil)
      condition = { "field" => "company.name", "operator" => "eq", "value" => "Acme" }
      expect {
        described_class.evaluate_any(record_nil_company, condition)
      }.to raise_error(LcpRuby::ConditionError, /intermediate value is nil/)
    end

    it "allows nil leaf value for present/blank operators" do
      company_nil_country = OpenStruct.new(name: "Acme", country: OpenStruct.new(code: nil))
      record_nil_leaf = OpenStruct.new(company: company_nil_country)
      condition = { "field" => "company.country.code", "operator" => "blank" }
      expect(described_class.evaluate_any(record_nil_leaf, condition)).to be true
    end
  end

  describe "dynamic value references" do
    it "resolves field_ref to another field on the same record" do
      condition = { "field" => "amount", "operator" => "lte", "value" => { "field_ref" => "budget_limit" } }
      expect(described_class.evaluate_any(record, condition)).to be true
    end

    it "resolves field_ref with dot-path" do
      company = OpenStruct.new(credit_limit: 300.0)
      rec = OpenStruct.new(amount: 500.0, company: company)
      condition = { "field" => "amount", "operator" => "gt", "value" => { "field_ref" => "company.credit_limit" } }
      expect(described_class.evaluate_any(rec, condition)).to be true
    end

    it "resolves current_user attribute" do
      user = OpenStruct.new(id: 42)
      condition = { "field" => "author_id", "operator" => "eq", "value" => { "current_user" => "id" } }
      expect(described_class.evaluate_any(record, condition, context: { current_user: user })).to be true
    end

    it "raises when current_user is missing from context" do
      condition = { "field" => "author_id", "operator" => "eq", "value" => { "current_user" => "id" } }
      expect {
        described_class.evaluate_any(record, condition, context: {})
      }.to raise_error(LcpRuby::ConditionError, /requires context\[:current_user\]/)
    end

    it "resolves date: today" do
      record_with_date = OpenStruct.new(due_date: Date.current - 1)
      condition = { "field" => "due_date", "operator" => "lt", "value" => { "date" => "today" } }
      expect(described_class.evaluate_any(record_with_date, condition)).to be true
    end

    it "resolves date: now" do
      record_with_time = OpenStruct.new(expires_at: Time.current + 3600)
      condition = { "field" => "expires_at", "operator" => "gt", "value" => { "date" => "now" } }
      expect(described_class.evaluate_any(record_with_time, condition)).to be true
    end

    it "raises for unknown date reference" do
      condition = { "field" => "amount", "operator" => "gt", "value" => { "date" => "yesterday" } }
      expect {
        described_class.evaluate_any(record, condition)
      }.to raise_error(LcpRuby::ConditionError, /unknown date reference/)
    end

    it "uses native comparison for Date values" do
      today = Date.current
      record_with_date = OpenStruct.new(due_date: today + 1)
      condition = { "field" => "due_date", "operator" => "gt", "value" => { "date" => "today" } }
      expect(described_class.evaluate_any(record_with_date, condition)).to be true
    end

    it "uses native comparison for Numeric values" do
      condition = { "field" => "amount", "operator" => "lt", "value" => { "field_ref" => "budget_limit" } }
      expect(described_class.evaluate_any(record, condition)).to be true
    end

    it "falls back to .to_f for backward compatibility with literal numerics" do
      expect(described_class.evaluate_any(record, { "field" => "amount", "operator" => "gt", "value" => 100 })).to be true
    end

    context "value service" do
      before { LcpRuby::ConditionServiceRegistry.clear! }

      it "resolves a value service" do
        service = Class.new do
          def self.call(record, **params)
            params[:threshold] || 999
          end
        end
        LcpRuby::ConditionServiceRegistry.register("threshold_service", service)

        condition = {
          "field" => "amount",
          "operator" => "lt",
          "value" => { "service" => "threshold_service", "params" => { "threshold" => 1000 } }
        }
        expect(described_class.evaluate_any(record, condition)).to be true
      end

      it "resolves params with nested references" do
        service = Class.new do
          def self.call(record, **params)
            params[:limit]
          end
        end
        LcpRuby::ConditionServiceRegistry.register("limit_service", service)

        condition = {
          "field" => "amount",
          "operator" => "lte",
          "value" => {
            "service" => "limit_service",
            "params" => { "limit" => { "field_ref" => "budget_limit" } }
          }
        }
        expect(described_class.evaluate_any(record, condition)).to be true
      end
    end

    context "lookup value reference" do
      let(:tax_limit_model) do
        Class.new do
          def self.find_by(attrs)
            if attrs["key"] == "vat_a"
              OpenStruct.new(key: "vat_a", threshold: 1000.0)
            end
          end
        end
      end

      before do
        registry = LcpRuby.registry
        allow(registry).to receive(:model_for).with("tax_limit").and_return(tax_limit_model)
      end

      it "resolves a lookup value" do
        condition = {
          "field" => "amount",
          "operator" => "lt",
          "value" => { "lookup" => "tax_limit", "match" => { "key" => "vat_a" }, "pick" => "threshold" }
        }
        expect(described_class.evaluate_any(record, condition)).to be true
      end

      it "resolves dynamic match values (field_ref)" do
        rec = OpenStruct.new(amount: 500.0, tax_key: "vat_a")
        allow(LcpRuby.registry).to receive(:model_for).with("tax_limit").and_return(tax_limit_model)

        condition = {
          "field" => "amount",
          "operator" => "lt",
          "value" => {
            "lookup" => "tax_limit",
            "match" => { "key" => { "field_ref" => "tax_key" } },
            "pick" => "threshold"
          }
        }
        expect(described_class.evaluate_any(rec, condition)).to be true
      end

      it "raises when model is not registered" do
        allow(LcpRuby.registry).to receive(:model_for).with("unknown").and_raise(LcpRuby::MetadataError, "not found")

        condition = {
          "field" => "amount",
          "operator" => "lt",
          "value" => { "lookup" => "unknown", "match" => { "key" => "x" }, "pick" => "val" }
        }
        expect {
          described_class.evaluate_any(record, condition)
        }.to raise_error(LcpRuby::ConditionError, /model 'unknown' is not registered/)
      end

      it "raises when no matching record is found" do
        condition = {
          "field" => "amount",
          "operator" => "lt",
          "value" => { "lookup" => "tax_limit", "match" => { "key" => "nonexistent" }, "pick" => "threshold" }
        }
        expect {
          described_class.evaluate_any(record, condition)
        }.to raise_error(LcpRuby::ConditionError, /no record found/)
      end

      it "raises when pick field does not exist on matched record" do
        condition = {
          "field" => "amount",
          "operator" => "lt",
          "value" => { "lookup" => "tax_limit", "match" => { "key" => "vat_a" }, "pick" => "nonexistent" }
        }
        expect {
          described_class.evaluate_any(record, condition)
        }.to raise_error(LcpRuby::ConditionError, /does not respond to 'nonexistent'/)
      end

      it "raises when nested lookup is attempted" do
        condition = {
          "field" => "amount",
          "operator" => "lt",
          "value" => {
            "lookup" => "tax_limit",
            "match" => { "key" => { "lookup" => "other", "match" => { "x" => "y" }, "pick" => "z" } },
            "pick" => "threshold"
          }
        }
        expect {
          described_class.evaluate_any(record, condition)
        }.to raise_error(LcpRuby::ConditionError, /nested lookup/)
      end

      it "raises when match key is missing" do
        condition = {
          "field" => "amount",
          "operator" => "lt",
          "value" => { "lookup" => "tax_limit", "pick" => "threshold" }
        }
        expect {
          described_class.evaluate_any(record, condition)
        }.to raise_error(LcpRuby::ConditionError, /missing required 'match' key/)
      end

      it "raises when pick key is missing" do
        condition = {
          "field" => "amount",
          "operator" => "lt",
          "value" => { "lookup" => "tax_limit", "match" => { "key" => "vat_a" } }
        }
        expect {
          described_class.evaluate_any(record, condition)
        }.to raise_error(LcpRuby::ConditionError, /missing required 'pick' key/)
      end
    end
  end

  describe "collection conditions" do
    let(:approval_approved) { OpenStruct.new(status: "approved", decision: "approved") }
    let(:approval_pending) { OpenStruct.new(status: "pending", decision: "pending") }
    let(:approval_rejected) { OpenStruct.new(status: "rejected", decision: "rejected") }

    let(:record_with_approvals) do
      OpenStruct.new(
        stage: "review",
        approvals: [ approval_approved, approval_pending ]
      )
    end

    it "evaluates 'any' quantifier — at least one matches" do
      condition = {
        "collection" => "approvals",
        "quantifier" => "any",
        "condition" => { "field" => "status", "operator" => "eq", "value" => "approved" }
      }
      expect(described_class.evaluate_any(record_with_approvals, condition)).to be true
    end

    it "evaluates 'all' quantifier — all must match" do
      condition = {
        "collection" => "approvals",
        "quantifier" => "all",
        "condition" => { "field" => "status", "operator" => "eq", "value" => "approved" }
      }
      expect(described_class.evaluate_any(record_with_approvals, condition)).to be false
    end

    it "evaluates 'none' quantifier — no match" do
      condition = {
        "collection" => "approvals",
        "quantifier" => "none",
        "condition" => { "field" => "status", "operator" => "eq", "value" => "rejected" }
      }
      expect(described_class.evaluate_any(record_with_approvals, condition)).to be true
    end

    it "defaults to 'any' when quantifier is omitted" do
      condition = {
        "collection" => "approvals",
        "condition" => { "field" => "status", "operator" => "eq", "value" => "approved" }
      }
      expect(described_class.evaluate_any(record_with_approvals, condition)).to be true
    end

    it "raises for unknown quantifier" do
      condition = {
        "collection" => "approvals",
        "quantifier" => "some",
        "condition" => { "field" => "status", "operator" => "eq", "value" => "x" }
      }
      expect {
        described_class.evaluate_any(record_with_approvals, condition)
      }.to raise_error(LcpRuby::ConditionError, /unknown collection quantifier/)
    end

    it "raises when collection does not exist" do
      condition = {
        "collection" => "nonexistent",
        "quantifier" => "any",
        "condition" => { "field" => "status", "operator" => "eq", "value" => "x" }
      }
      expect {
        described_class.evaluate_any(record_with_approvals, condition)
      }.to raise_error(LcpRuby::ConditionError, /does not respond to collection/)
    end

    it "handles empty collection with 'any' (false)" do
      rec = OpenStruct.new(approvals: [])
      condition = {
        "collection" => "approvals",
        "quantifier" => "any",
        "condition" => { "field" => "status", "operator" => "eq", "value" => "approved" }
      }
      expect(described_class.evaluate_any(rec, condition)).to be false
    end

    it "handles empty collection with 'all' (true — vacuous)" do
      rec = OpenStruct.new(approvals: [])
      condition = {
        "collection" => "approvals",
        "quantifier" => "all",
        "condition" => { "field" => "status", "operator" => "eq", "value" => "approved" }
      }
      expect(described_class.evaluate_any(rec, condition)).to be true
    end

    it "handles empty collection with 'none' (true)" do
      rec = OpenStruct.new(approvals: [])
      condition = {
        "collection" => "approvals",
        "quantifier" => "none",
        "condition" => { "field" => "status", "operator" => "eq", "value" => "rejected" }
      }
      expect(described_class.evaluate_any(rec, condition)).to be true
    end

    it "supports inner compound condition" do
      condition = {
        "collection" => "approvals",
        "quantifier" => "any",
        "condition" => {
          "all" => [
            { "field" => "status", "operator" => "eq", "value" => "approved" },
            { "field" => "decision", "operator" => "eq", "value" => "approved" }
          ]
        }
      }
      expect(described_class.evaluate_any(record_with_approvals, condition)).to be true
    end

    it "supports inner dot-path condition" do
      author = OpenStruct.new(name: "john.smith")
      comment = OpenStruct.new(author: author, text: "Good")
      rec = OpenStruct.new(comments: [ comment ])

      condition = {
        "collection" => "comments",
        "quantifier" => "any",
        "condition" => { "field" => "author.name", "operator" => "eq", "value" => "john.smith" }
      }
      expect(described_class.evaluate_any(rec, condition)).to be true
    end

    it "works nested inside compound conditions" do
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
      expect(described_class.evaluate_any(record_with_approvals, condition)).to be true
    end
  end

  describe "array operators" do
    let(:record_with_array) do
      OpenStruct.new(tags: %w[ruby rails python], scores: [1, 2, 3], empty_tags: [])
    end

    describe "contains (polymorphic)" do
      it "checks array containment when actual is Array" do
        expect(described_class.evaluate_any(record_with_array, { "field" => "tags", "operator" => "contains", "value" => "ruby" })).to be true
        expect(described_class.evaluate_any(record_with_array, { "field" => "tags", "operator" => "contains", "value" => "java" })).to be false
      end

      it "checks all values for array containment" do
        expect(described_class.evaluate_any(record_with_array, { "field" => "tags", "operator" => "contains", "value" => %w[ruby rails] })).to be true
        expect(described_class.evaluate_any(record_with_array, { "field" => "tags", "operator" => "contains", "value" => %w[ruby java] })).to be false
      end

      it "still does string substring matching for non-arrays" do
        record = OpenStruct.new(name: "Test Record")
        expect(described_class.evaluate_any(record, { "field" => "name", "operator" => "contains", "value" => "test" })).to be true
      end
    end

    describe "not_contains" do
      it "is true when array does not contain value" do
        expect(described_class.evaluate_any(record_with_array, { "field" => "tags", "operator" => "not_contains", "value" => "java" })).to be true
      end

      it "is false when array contains value" do
        expect(described_class.evaluate_any(record_with_array, { "field" => "tags", "operator" => "not_contains", "value" => "ruby" })).to be false
      end

      it "does string not-contains for non-arrays" do
        record = OpenStruct.new(name: "Hello")
        expect(described_class.evaluate_any(record, { "field" => "name", "operator" => "not_contains", "value" => "xyz" })).to be true
        expect(described_class.evaluate_any(record, { "field" => "name", "operator" => "not_contains", "value" => "hello" })).to be false
      end
    end

    describe "any_of" do
      it "is true when array contains any of the values" do
        expect(described_class.evaluate_any(record_with_array, { "field" => "tags", "operator" => "any_of", "value" => %w[java ruby] })).to be true
      end

      it "is false when array contains none of the values" do
        expect(described_class.evaluate_any(record_with_array, { "field" => "tags", "operator" => "any_of", "value" => %w[java go] })).to be false
      end
    end

    describe "empty" do
      it "is true for empty array" do
        expect(described_class.evaluate_any(record_with_array, { "field" => "empty_tags", "operator" => "empty" })).to be true
      end

      it "is false for non-empty array" do
        expect(described_class.evaluate_any(record_with_array, { "field" => "tags", "operator" => "empty" })).to be false
      end
    end

    describe "not_empty" do
      it "is true for non-empty array" do
        expect(described_class.evaluate_any(record_with_array, { "field" => "tags", "operator" => "not_empty" })).to be true
      end

      it "is false for empty array" do
        expect(described_class.evaluate_any(record_with_array, { "field" => "empty_tags", "operator" => "not_empty" })).to be false
      end
    end
  end
end
