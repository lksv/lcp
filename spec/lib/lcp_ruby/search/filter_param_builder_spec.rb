require "spec_helper"

RSpec.describe LcpRuby::Search::FilterParamBuilder do
  include ActiveSupport::Testing::TimeHelpers

  describe ".build" do
    it "returns empty hash for nil input" do
      expect(described_class.build(nil)).to eq({})
    end

    it "returns empty hash for empty hash" do
      expect(described_class.build({})).to eq({})
    end

    context "simple conditions (children format)" do
      it "converts a single condition to Ransack param" do
        tree = {
          "combinator" => "and",
          "children" => [
            { "field" => "title", "operator" => "cont", "value" => "Acme" }
          ]
        }
        result = described_class.build(tree)
        expect(result[:ransack]).to eq("title_cont" => "Acme")
        expect(result[:custom_fields]).to eq({})
      end

      it "converts multiple conditions" do
        tree = {
          "combinator" => "and",
          "children" => [
            { "field" => "title", "operator" => "cont", "value" => "Acme" },
            { "field" => "value", "operator" => "gteq", "value" => 10000 }
          ]
        }
        result = described_class.build(tree)
        expect(result[:ransack]).to eq("title_cont" => "Acme", "value_gteq" => 10000)
      end

      it "skips conditions with blank field" do
        tree = {
          "combinator" => "and",
          "children" => [
            { "field" => "", "operator" => "cont", "value" => "Acme" }
          ]
        }
        result = described_class.build(tree)
        expect(result[:ransack]).to eq({})
      end

      it "skips conditions with blank operator" do
        tree = {
          "combinator" => "and",
          "children" => [
            { "field" => "title", "operator" => "", "value" => "Acme" }
          ]
        }
        result = described_class.build(tree)
        expect(result[:ransack]).to eq({})
      end
    end

    context "association dot-path conversion" do
      it "converts dot-path to Ransack underscore format" do
        tree = {
          "combinator" => "and",
          "children" => [
            { "field" => "company.name", "operator" => "cont", "value" => "Corp" }
          ]
        }
        result = described_class.build(tree)
        expect(result[:ransack]).to eq("company_name_cont" => "Corp")
      end

      it "handles multi-level association paths" do
        tree = {
          "combinator" => "and",
          "children" => [
            { "field" => "contact.company.country", "operator" => "eq", "value" => "CZ" }
          ]
        }
        result = described_class.build(tree)
        expect(result[:ransack]).to eq("contact_company_country_eq" => "CZ")
      end
    end

    context "between expansion" do
      it "expands between into gteq and lteq" do
        tree = {
          "combinator" => "and",
          "children" => [
            { "field" => "value", "operator" => "between", "value" => [ 100, 500 ] }
          ]
        }
        result = described_class.build(tree)
        expect(result[:ransack]).to eq("value_gteq" => 100, "value_lteq" => 500)
      end

      it "ignores between with non-array value" do
        tree = {
          "combinator" => "and",
          "children" => [
            { "field" => "value", "operator" => "between", "value" => "invalid" }
          ]
        }
        result = described_class.build(tree)
        expect(result[:ransack]).to eq({})
      end

      it "ignores between with wrong array size" do
        tree = {
          "combinator" => "and",
          "children" => [
            { "field" => "value", "operator" => "between", "value" => [ 100 ] }
          ]
        }
        result = described_class.build(tree)
        expect(result[:ransack]).to eq({})
      end
    end

    context "relative date operators" do
      around do |example|
        travel_to Date.new(2024, 6, 15) do
          example.run
        end
      end

      it "expands last_n_days" do
        tree = {
          "combinator" => "and",
          "children" => [
            { "field" => "created_at", "operator" => "last_n_days", "value" => 7 }
          ]
        }
        result = described_class.build(tree)[:ransack]
        expect(result).to have_key("created_at_gteq")
        expect(result["created_at_gteq"]).to eq(7.days.ago.beginning_of_day.iso8601)
      end

      it "expands this_week" do
        tree = {
          "combinator" => "and",
          "children" => [
            { "field" => "created_at", "operator" => "this_week" }
          ]
        }
        result = described_class.build(tree)[:ransack]
        expect(result["created_at_gteq"]).to eq(Date.current.beginning_of_week.iso8601)
        expect(result["created_at_lteq"]).to eq(Date.current.end_of_week.iso8601)
      end

      it "expands this_month" do
        tree = {
          "combinator" => "and",
          "children" => [
            { "field" => "created_at", "operator" => "this_month" }
          ]
        }
        result = described_class.build(tree)[:ransack]
        expect(result["created_at_gteq"]).to eq(Date.new(2024, 6, 1).iso8601)
        expect(result["created_at_lteq"]).to eq(Date.new(2024, 6, 30).iso8601)
      end

      it "expands this_quarter" do
        tree = {
          "combinator" => "and",
          "children" => [
            { "field" => "created_at", "operator" => "this_quarter" }
          ]
        }
        result = described_class.build(tree)[:ransack]
        expect(result["created_at_gteq"]).to eq(Date.new(2024, 4, 1).iso8601)
        expect(result["created_at_lteq"]).to eq(Date.new(2024, 6, 30).iso8601)
      end

      it "expands this_year" do
        tree = {
          "combinator" => "and",
          "children" => [
            { "field" => "created_at", "operator" => "this_year" }
          ]
        }
        result = described_class.build(tree)[:ransack]
        expect(result["created_at_gteq"]).to eq(Date.new(2024, 1, 1).iso8601)
        expect(result["created_at_lteq"]).to eq(Date.new(2024, 12, 31).iso8601)
      end
    end

    context "nested groups (recursive)" do
      it "builds flat AND children as flat Ransack params" do
        tree = {
          "combinator" => "and",
          "children" => [
            { "field" => "name", "operator" => "cont", "value" => "Acme" },
            { "field" => "price", "operator" => "gteq", "value" => 100 }
          ]
        }
        result = described_class.build(tree)[:ransack]
        expect(result).to eq("name_cont" => "Acme", "price_gteq" => 100)
        expect(result).not_to have_key("g")
      end

      it "builds nested OR group as Ransack g[0]" do
        tree = {
          "combinator" => "and",
          "children" => [
            { "field" => "name", "operator" => "cont", "value" => "Acme" },
            {
              "combinator" => "or",
              "children" => [
                { "field" => "stage", "operator" => "eq", "value" => "lead" },
                { "field" => "stage", "operator" => "eq", "value" => "prospect" }
              ]
            }
          ]
        }
        result = described_class.build(tree)[:ransack]
        expect(result["name_cont"]).to eq("Acme")
        expect(result["g"]["0"]["m"]).to eq("or")
        expect(result["g"]["0"]["stage_eq"]).to eq("prospect") # last write wins
      end

      it "builds group within group as nested g[N][g][M]" do
        tree = {
          "combinator" => "and",
          "children" => [
            {
              "combinator" => "or",
              "children" => [
                { "field" => "a", "operator" => "eq", "value" => "1" },
                {
                  "combinator" => "and",
                  "children" => [
                    { "field" => "b", "operator" => "eq", "value" => "2" },
                    { "field" => "c", "operator" => "eq", "value" => "3" }
                  ]
                }
              ]
            }
          ]
        }
        result = described_class.build(tree)[:ransack]
        # Top-level group g[0] is OR
        expect(result["g"]["0"]["m"]).to eq("or")
        expect(result["g"]["0"]["a_eq"]).to eq("1")
        # Nested group within g[0] is AND
        expect(result["g"]["0"]["g"]["1"]["m"]).to eq("and")
        expect(result["g"]["0"]["g"]["1"]["b_eq"]).to eq("2")
        expect(result["g"]["0"]["g"]["1"]["c_eq"]).to eq("3")
      end

      it "sets root combinator m=or when root is OR" do
        tree = {
          "combinator" => "or",
          "children" => [
            {
              "combinator" => "and",
              "children" => [
                { "field" => "stage", "operator" => "eq", "value" => "proposal" },
                { "field" => "value", "operator" => "gt", "value" => "50000" }
              ]
            },
            {
              "combinator" => "and",
              "children" => [
                { "field" => "stage", "operator" => "eq", "value" => "negotiation" },
                { "field" => "value", "operator" => "gt", "value" => "100000" }
              ]
            }
          ]
        }
        result = described_class.build(tree)[:ransack]
        expect(result["m"]).to eq("or")
        expect(result["g"]["0"]["m"]).to eq("and")
        expect(result["g"]["0"]["stage_eq"]).to eq("proposal")
        expect(result["g"]["0"]["value_gt"]).to eq("50000")
        expect(result["g"]["1"]["m"]).to eq("and")
        expect(result["g"]["1"]["stage_eq"]).to eq("negotiation")
        expect(result["g"]["1"]["value_gt"]).to eq("100000")
      end

      it "does not set root combinator when root is AND (default)" do
        tree = {
          "combinator" => "and",
          "children" => [
            { "field" => "name", "operator" => "cont", "value" => "Acme" }
          ]
        }
        result = described_class.build(tree)[:ransack]
        expect(result).not_to have_key("m")
      end

      it "extracts custom fields from nested children correctly" do
        tree = {
          "combinator" => "and",
          "children" => [
            { "field" => "title", "operator" => "cont", "value" => "Acme" },
            { "field" => "cf[tag]", "operator" => "eq", "value" => "ruby" }
          ]
        }
        result = described_class.build(tree)
        expect(result[:ransack]).to eq("title_cont" => "Acme")
        expect(result[:custom_fields]["cf[tag]"]).to eq(operator: :eq, value: "ruby")
      end
    end

    context "no-value operators" do
      it "provides sentinel value for boolean true operator" do
        tree = {
          "combinator" => "and",
          "children" => [
            { "field" => "published", "operator" => "true" }
          ]
        }
        result = described_class.build(tree)[:ransack]
        expect(result["published_true"]).to eq(1)
      end

      it "provides sentinel value for boolean false operator" do
        tree = {
          "combinator" => "and",
          "children" => [
            { "field" => "published", "operator" => "false" }
          ]
        }
        result = described_class.build(tree)[:ransack]
        expect(result["published_false"]).to eq(1)
      end

      it "provides sentinel value for present operator" do
        tree = {
          "combinator" => "and",
          "children" => [
            { "field" => "name", "operator" => "present" }
          ]
        }
        result = described_class.build(tree)[:ransack]
        expect(result["name_present"]).to eq(1)
      end

      it "provides sentinel value for blank operator" do
        tree = {
          "combinator" => "and",
          "children" => [
            { "field" => "name", "operator" => "blank" }
          ]
        }
        result = described_class.build(tree)[:ransack]
        expect(result["name_blank"]).to eq(1)
      end

      it "provides sentinel value for null operator" do
        tree = {
          "combinator" => "and",
          "children" => [
            { "field" => "name", "operator" => "null" }
          ]
        }
        result = described_class.build(tree)[:ransack]
        expect(result["name_null"]).to eq(1)
      end

      it "provides sentinel value for not_null operator" do
        tree = {
          "combinator" => "and",
          "children" => [
            { "field" => "name", "operator" => "not_null" }
          ]
        }
        result = described_class.build(tree)[:ransack]
        expect(result["name_not_null"]).to eq(1)
      end

      it "preserves explicit value when provided for no-value operator" do
        tree = {
          "combinator" => "and",
          "children" => [
            { "field" => "published", "operator" => "true", "value" => "yes" }
          ]
        }
        result = described_class.build(tree)[:ransack]
        expect(result["published_true"]).to eq("yes")
      end
    end

    context "legacy format support" do
      it "handles legacy {conditions, groups} format" do
        tree = {
          "conditions" => [
            { "field" => "title", "operator" => "cont", "value" => "Acme" }
          ],
          "groups" => [
            {
              "combinator" => "or",
              "conditions" => [
                { "field" => "stage", "operator" => "eq", "value" => "lead" },
                { "field" => "stage", "operator" => "eq", "value" => "prospect" }
              ]
            }
          ]
        }
        result = described_class.build(tree)
        expect(result[:ransack]["title_cont"]).to eq("Acme")
        expect(result[:ransack]["g"]["0"]["m"]).to eq("or")
      end
    end
  end

  describe ".dot_path_to_ransack" do
    it "converts single dot to underscore" do
      expect(described_class.dot_path_to_ransack("company.name")).to eq("company_name")
    end

    it "converts multiple dots" do
      expect(described_class.dot_path_to_ransack("contact.company.country")).to eq("contact_company_country")
    end

    it "handles no dots" do
      expect(described_class.dot_path_to_ransack("title")).to eq("title")
    end
  end
end
