require "spec_helper"

RSpec.describe LcpRuby::HashUtils do
  describe ".stringify_deep" do
    it "converts symbol keys to strings" do
      expect(described_class.stringify_deep({ foo: "bar" })).to eq({ "foo" => "bar" })
    end

    it "converts nested hash symbol keys" do
      input = { outer: { inner: "value" } }
      expected = { "outer" => { "inner" => "value" } }
      expect(described_class.stringify_deep(input)).to eq(expected)
    end

    it "converts symbol values to strings" do
      expect(described_class.stringify_deep({ foo: :bar })).to eq({ "foo" => "bar" })
    end

    it "recurses into arrays" do
      input = [ { foo: :bar }, { baz: "qux" } ]
      expected = [ { "foo" => "bar" }, { "baz" => "qux" } ]
      expect(described_class.stringify_deep(input)).to eq(expected)
    end

    it "passes through strings unchanged" do
      expect(described_class.stringify_deep("hello")).to eq("hello")
    end

    it "passes through integers unchanged" do
      expect(described_class.stringify_deep(42)).to eq(42)
    end

    it "passes through nil unchanged" do
      expect(described_class.stringify_deep(nil)).to be_nil
    end

    it "passes through booleans unchanged" do
      expect(described_class.stringify_deep(true)).to eq(true)
      expect(described_class.stringify_deep(false)).to eq(false)
    end

    it "handles deeply nested mixed structures" do
      input = { a: [ { b: :c }, "d" ], e: { f: { g: :h } } }
      expected = { "a" => [ { "b" => "c" }, "d" ], "e" => { "f" => { "g" => "h" } } }
      expect(described_class.stringify_deep(input)).to eq(expected)
    end

    it "handles already-stringified hashes" do
      input = { "already" => "stringified" }
      expect(described_class.stringify_deep(input)).to eq({ "already" => "stringified" })
    end

    context "with Proc values (condition builder blocks)" do
      it "resolves a simple field condition proc" do
        condition = proc { field(:status).eq("active") }
        result = described_class.stringify_deep(condition)
        expect(result).to eq({ "field" => "status", "operator" => "eq", "value" => "active" })
      end

      it "resolves a compound all condition proc" do
        condition = proc {
          all do
            field(:status).eq("active")
            field(:priority).eq("high")
          end
        }
        result = described_class.stringify_deep(condition)
        expect(result).to eq({
          "all" => [
            { "field" => "status", "operator" => "eq", "value" => "active" },
            { "field" => "priority", "operator" => "eq", "value" => "high" }
          ]
        })
      end

      it "resolves a compound any condition proc" do
        condition = proc {
          any do
            field(:status).eq("draft")
            field(:status).eq("review")
          end
        }
        result = described_class.stringify_deep(condition)
        expect(result).to eq({
          "any" => [
            { "field" => "status", "operator" => "eq", "value" => "draft" },
            { "field" => "status", "operator" => "eq", "value" => "review" }
          ]
        })
      end

      it "resolves a not condition proc" do
        condition = proc {
          not_condition do
            field(:status).eq("closed")
          end
        }
        result = described_class.stringify_deep(condition)
        expect(result).to eq({ "not" => { "field" => "status", "operator" => "eq", "value" => "closed" } })
      end

      it "resolves a collection condition proc" do
        condition = proc {
          collection(:tasks, quantifier: :any) do
            field(:status).eq("approved")
          end
        }
        result = described_class.stringify_deep(condition)
        expect(result).to eq({
          "collection" => "tasks",
          "quantifier" => "any",
          "condition" => { "field" => "status", "operator" => "eq", "value" => "approved" }
        })
      end

      it "resolves a proc with value references" do
        condition = proc {
          field(:amount).gt({ "field_ref" => "budget_limit" })
        }
        result = described_class.stringify_deep(condition)
        expect(result).to eq({
          "field" => "amount",
          "operator" => "gt",
          "value" => { "field_ref" => "budget_limit" }
        })
      end

      it "resolves a proc nested inside a hash value" do
        input = {
          "class" => "lcp-row-danger",
          when: proc {
            field(:status).eq("closed")
          }
        }
        result = described_class.stringify_deep(input)
        expect(result).to eq({
          "class" => "lcp-row-danger",
          "when" => { "field" => "status", "operator" => "eq", "value" => "closed" }
        })
      end
    end
  end
end
