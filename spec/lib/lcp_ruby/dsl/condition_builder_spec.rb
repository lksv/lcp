require "spec_helper"

RSpec.describe LcpRuby::Dsl::ConditionBuilder do
  describe ".build" do
    it "builds a simple field condition" do
      result = described_class.build do
        field(:status).eq("active")
      end

      expect(result).to eq({
        "field" => "status",
        "operator" => "eq",
        "value" => "active"
      })
    end

    it "builds a present condition (no value)" do
      result = described_class.build do
        field(:title).present
      end

      expect(result).to eq({
        "field" => "title",
        "operator" => "present"
      })
    end

    it "builds an 'all' compound condition" do
      result = described_class.build do
        all do
          field(:status).eq("active")
          field(:amount).gt(0)
        end
      end

      expect(result).to eq({
        "all" => [
          { "field" => "status", "operator" => "eq", "value" => "active" },
          { "field" => "amount", "operator" => "gt", "value" => 0 }
        ]
      })
    end

    it "builds an 'any' compound condition" do
      result = described_class.build do
        any do
          field(:role).eq("admin")
          field(:stage).eq("draft")
        end
      end

      expect(result).to eq({
        "any" => [
          { "field" => "role", "operator" => "eq", "value" => "admin" },
          { "field" => "stage", "operator" => "eq", "value" => "draft" }
        ]
      })
    end

    it "builds a 'not' condition" do
      result = described_class.build do
        not_condition do
          field(:stage).eq("closed")
        end
      end

      expect(result).to eq({
        "not" => { "field" => "stage", "operator" => "eq", "value" => "closed" }
      })
    end

    it "builds nested compound conditions" do
      result = described_class.build do
        all do
          field(:status).eq("active")
          any do
            field(:amount).gt(1000)
            field(:priority).eq("high")
          end
        end
      end

      expect(result).to eq({
        "all" => [
          { "field" => "status", "operator" => "eq", "value" => "active" },
          {
            "any" => [
              { "field" => "amount", "operator" => "gt", "value" => 1000 },
              { "field" => "priority", "operator" => "eq", "value" => "high" }
            ]
          }
        ]
      })
    end

    it "builds a collection condition" do
      result = described_class.build do
        collection(:approvals, quantifier: :any) do
          field(:status).eq("approved")
        end
      end

      expect(result).to eq({
        "collection" => "approvals",
        "quantifier" => "any",
        "condition" => { "field" => "status", "operator" => "eq", "value" => "approved" }
      })
    end

    it "builds a collection with compound inner condition" do
      result = described_class.build do
        collection(:items, quantifier: :all) do
          field(:status).eq("approved")
          field(:price).gt(0)
        end
      end

      expect(result).to eq({
        "collection" => "items",
        "quantifier" => "all",
        "condition" => {
          "all" => [
            { "field" => "status", "operator" => "eq", "value" => "approved" },
            { "field" => "price", "operator" => "gt", "value" => 0 }
          ]
        }
      })
    end

    it "supports field_ref value reference" do
      result = described_class.build do
        field(:amount).gt(field_ref: "budget_limit")
      end

      expect(result).to eq({
        "field" => "amount",
        "operator" => "gt",
        "value" => { "field_ref" => "budget_limit" }
      })
    end

    it "supports current_user value reference" do
      result = described_class.build do
        field(:author_id).eq(current_user: "id")
      end

      expect(result).to eq({
        "field" => "author_id",
        "operator" => "eq",
        "value" => { "current_user" => "id" }
      })
    end

    it "supports date value reference" do
      result = described_class.build do
        field(:due_date).lt(date: "today")
      end

      expect(result).to eq({
        "field" => "due_date",
        "operator" => "lt",
        "value" => { "date" => "today" }
      })
    end

    it "supports dot-path fields" do
      result = described_class.build do
        field("company.industry").eq("finance")
      end

      expect(result).to eq({
        "field" => "company.industry",
        "operator" => "eq",
        "value" => "finance"
      })
    end

    it "supports all operators" do
      operators = {
        eq: [ "active" ], not_eq: [ "x" ], gt: [ 1 ], gte: [ 1 ], lt: [ 1 ], lte: [ 1 ],
        in: [ %w[a b] ], not_in: [ %w[a b] ],
        starts_with: [ "x" ], ends_with: [ "x" ], contains: [ "x" ],
        matches: [ "^x$" ], not_matches: [ "^x$" ]
      }

      operators.each do |op, args|
        result = described_class.build { field(:f).send(op, *args) }
        expect(result["operator"]).to eq(op.to_s), "Expected operator #{op}"
      end
    end

    it "wraps multiple top-level conditions in 'all'" do
      result = described_class.build do
        field(:status).eq("active")
        field(:amount).gt(0)
      end

      expect(result).to eq({
        "all" => [
          { "field" => "status", "operator" => "eq", "value" => "active" },
          { "field" => "amount", "operator" => "gt", "value" => 0 }
        ]
      })
    end

    it "raises on empty block" do
      expect {
        described_class.build { }
      }.to raise_error(ArgumentError, /empty/)
    end

    it "builds a lookup value reference" do
      result = described_class.lookup(:tax_limit, match: { key: "vat_a" }, pick: :threshold)

      expect(result).to eq({
        "lookup" => "tax_limit",
        "match" => { "key" => "vat_a" },
        "pick" => "threshold"
      })
    end

    it "builds a lookup with dynamic match values" do
      result = described_class.lookup(:tax_limit, match: { key: { field_ref: "tax_key" } }, pick: :threshold)

      expect(result).to eq({
        "lookup" => "tax_limit",
        "match" => { "key" => { "field_ref" => "tax_key" } },
        "pick" => "threshold"
      })
    end

    it "uses lookup in a condition" do
      result = described_class.build do
        field(:price).lt(LcpRuby::Dsl::ConditionBuilder.lookup(:tax_limit, match: { key: "vat_a" }, pick: :threshold))
      end

      expect(result).to eq({
        "field" => "price",
        "operator" => "lt",
        "value" => { "lookup" => "tax_limit", "match" => { "key" => "vat_a" }, "pick" => "threshold" }
      })
    end

    it "supports service conditions" do
      result = described_class.build do
        service("credit_check")
      end

      expect(result).to eq({
        "service" => "credit_check"
      })
    end
  end
end
