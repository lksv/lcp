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

    context "simple conditions" do
      it "converts a single condition to Ransack param" do
        tree = {
          "conditions" => [
            { "field" => "title", "operator" => "cont", "value" => "Acme" }
          ]
        }
        result = described_class.build(tree)
        expect(result[:ransack]).to eq("title_cont" => "Acme")
        expect(result[:custom_fields]).to eq({})
      end

      it "converts multiple conditions" do
        tree = {
          "conditions" => [
            { "field" => "title", "operator" => "cont", "value" => "Acme" },
            { "field" => "value", "operator" => "gteq", "value" => 10000 }
          ]
        }
        result = described_class.build(tree)
        expect(result[:ransack]).to eq("title_cont" => "Acme", "value_gteq" => 10000)
      end

      it "skips conditions with blank field" do
        tree = {
          "conditions" => [
            { "field" => "", "operator" => "cont", "value" => "Acme" }
          ]
        }
        result = described_class.build(tree)
        expect(result[:ransack]).to eq({})
      end

      it "skips conditions with blank operator" do
        tree = {
          "conditions" => [
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
          "conditions" => [
            { "field" => "company.name", "operator" => "cont", "value" => "Corp" }
          ]
        }
        result = described_class.build(tree)
        expect(result[:ransack]).to eq("company_name_cont" => "Corp")
      end

      it "handles multi-level association paths" do
        tree = {
          "conditions" => [
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
          "conditions" => [
            { "field" => "value", "operator" => "between", "value" => [100, 500] }
          ]
        }
        result = described_class.build(tree)
        expect(result[:ransack]).to eq("value_gteq" => 100, "value_lteq" => 500)
      end

      it "ignores between with non-array value" do
        tree = {
          "conditions" => [
            { "field" => "value", "operator" => "between", "value" => "invalid" }
          ]
        }
        result = described_class.build(tree)
        expect(result[:ransack]).to eq({})
      end

      it "ignores between with wrong array size" do
        tree = {
          "conditions" => [
            { "field" => "value", "operator" => "between", "value" => [100] }
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
          "conditions" => [
            { "field" => "created_at", "operator" => "last_n_days", "value" => 7 }
          ]
        }
        result = described_class.build(tree)[:ransack]
        expect(result).to have_key("created_at_gteq")
        expect(result["created_at_gteq"]).to eq(7.days.ago.beginning_of_day.iso8601)
      end

      it "expands this_week" do
        tree = {
          "conditions" => [
            { "field" => "created_at", "operator" => "this_week" }
          ]
        }
        result = described_class.build(tree)[:ransack]
        expect(result["created_at_gteq"]).to eq(Date.current.beginning_of_week.iso8601)
        expect(result["created_at_lteq"]).to eq(Date.current.end_of_week.iso8601)
      end

      it "expands this_month" do
        tree = {
          "conditions" => [
            { "field" => "created_at", "operator" => "this_month" }
          ]
        }
        result = described_class.build(tree)[:ransack]
        expect(result["created_at_gteq"]).to eq(Date.new(2024, 6, 1).iso8601)
        expect(result["created_at_lteq"]).to eq(Date.new(2024, 6, 30).iso8601)
      end

      it "expands this_quarter" do
        tree = {
          "conditions" => [
            { "field" => "created_at", "operator" => "this_quarter" }
          ]
        }
        result = described_class.build(tree)[:ransack]
        expect(result["created_at_gteq"]).to eq(Date.new(2024, 4, 1).iso8601)
        expect(result["created_at_lteq"]).to eq(Date.new(2024, 6, 30).iso8601)
      end

      it "expands this_year" do
        tree = {
          "conditions" => [
            { "field" => "created_at", "operator" => "this_year" }
          ]
        }
        result = described_class.build(tree)[:ransack]
        expect(result["created_at_gteq"]).to eq(Date.new(2024, 1, 1).iso8601)
        expect(result["created_at_lteq"]).to eq(Date.new(2024, 12, 31).iso8601)
      end
    end

    context "OR groups" do
      it "builds grouped conditions" do
        tree = {
          "conditions" => [],
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
        result = described_class.build(tree)[:ransack]
        expect(result).to have_key("g")
        expect(result["g"]["0"]["m"]).to eq("or")
        expect(result["g"]["0"]["stage_eq"]).to eq("prospect") # last write wins for same key
      end

      it "handles multiple groups" do
        tree = {
          "conditions" => [],
          "groups" => [
            {
              "combinator" => "and",
              "conditions" => [
                { "field" => "title", "operator" => "cont", "value" => "Acme" }
              ]
            },
            {
              "combinator" => "or",
              "conditions" => [
                { "field" => "value", "operator" => "gt", "value" => 1000 }
              ]
            }
          ]
        }
        result = described_class.build(tree)[:ransack]
        expect(result["g"]).to have_key("0")
        expect(result["g"]).to have_key("1")
      end
    end

    context "custom field extraction" do
      it "separates custom field conditions from Ransack params" do
        tree = {
          "conditions" => [
            { "field" => "title", "operator" => "cont", "value" => "Acme" },
            { "field" => "cf[tag]", "operator" => "eq", "value" => "ruby" }
          ]
        }
        result = described_class.build(tree)
        expect(result).to have_key(:ransack)
        expect(result).to have_key(:custom_fields)
        expect(result[:ransack]).to eq("title_cont" => "Acme")
        expect(result[:custom_fields]["cf[tag]"]).to eq(operator: :eq, value: "ruby")
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
