require "spec_helper"

RSpec.describe LcpRuby::SavedFilters::StaleFieldValidator do
  let(:filter_metadata) do
    {
      fields: [
        { name: "status" },
        { name: "name" },
        { name: "amount" }
      ]
    }
  end

  describe ".validate" do
    context "with all valid fields" do
      it "returns the tree unchanged" do
        tree = {
          "combinator" => "and",
          "children" => [
            { "field" => "status", "operator" => "eq", "value" => "active" },
            { "field" => "name", "operator" => "cont", "value" => "test" }
          ]
        }

        result = described_class.validate(tree, filter_metadata)
        expect(result[:skipped_conditions]).to be_empty
        expect(result[:valid_tree]["children"].size).to eq(2)
      end
    end

    context "with a stale field reference" do
      it "removes the invalid condition and reports it" do
        tree = {
          "combinator" => "and",
          "children" => [
            { "field" => "status", "operator" => "eq", "value" => "active" },
            { "field" => "removed_field", "operator" => "eq", "value" => "x" }
          ]
        }

        result = described_class.validate(tree, filter_metadata)
        expect(result[:skipped_conditions]).to include(a_string_matching(/removed_field/))
        # Single remaining child gets promoted from the group
        expect(result[:valid_tree]["field"]).to eq("status")
      end
    end

    context "with all fields stale" do
      it "returns an empty tree with skipped descriptions" do
        tree = {
          "combinator" => "and",
          "children" => [
            { "field" => "deleted_field", "operator" => "eq", "value" => "x" }
          ]
        }

        result = described_class.validate(tree, filter_metadata)
        expect(result[:skipped_conditions]).not_to be_empty
        expect(result[:valid_tree]["children"]).to be_empty
      end
    end

    context "with scope references" do
      it "always considers scope references valid" do
        tree = {
          "combinator" => "and",
          "children" => [
            { "field" => "@active", "operator" => "scope" },
            { "field" => "@custom_scope", "operator" => "scope", "params" => { "days" => 30 } }
          ]
        }

        result = described_class.validate(tree, filter_metadata)
        expect(result[:skipped_conditions]).to be_empty
        expect(result[:valid_tree]["children"].size).to eq(2)
      end
    end

    context "with nested groups" do
      it "removes stale conditions inside groups" do
        tree = {
          "combinator" => "and",
          "children" => [
            {
              "combinator" => "or",
              "children" => [
                { "field" => "status", "operator" => "eq", "value" => "active" },
                { "field" => "gone_field", "operator" => "eq", "value" => "x" }
              ]
            }
          ]
        }

        result = described_class.validate(tree, filter_metadata)
        expect(result[:skipped_conditions].size).to eq(1)
        # The group collapses to a single child, which gets promoted
        expect(result[:valid_tree]["field"]).to eq("status")
      end
    end

    context "with empty tree" do
      it "returns an empty valid tree" do
        result = described_class.validate({}, filter_metadata)
        expect(result[:valid_tree]["children"]).to be_empty
        expect(result[:skipped_conditions]).to be_empty
      end
    end
  end
end
