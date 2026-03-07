require "spec_helper"

RSpec.describe LcpRuby::DataSource::ApiFilterTranslator do
  let(:field_names) { %w[name address status floors] }

  describe ".translate" do
    it "translates simple Ransack params" do
      ransack = { "name_cont" => "tower", "status_eq" => "active" }

      filters = described_class.translate(ransack, field_names: field_names)

      expect(filters).to contain_exactly(
        { field: "name", operator: "cont", value: "tower" },
        { field: "status", operator: "eq", value: "active" }
      )
    end

    it "handles numeric predicates" do
      ransack = { "floors_gt" => "5", "floors_lteq" => "20" }

      filters = described_class.translate(ransack, field_names: field_names)

      expect(filters).to contain_exactly(
        { field: "floors", operator: "gt", value: "5" },
        { field: "floors", operator: "lteq", value: "20" }
      )
    end

    it "drops unknown predicates" do
      ransack = { "name_unknown" => "value" }

      filters = described_class.translate(ransack, field_names: field_names)
      expect(filters).to be_empty
    end

    it "drops unsupported operators" do
      ransack = { "name_cont" => "tower", "floors_gt" => "5" }

      filters = described_class.translate(
        ransack,
        field_names: field_names,
        supported_operators: %w[eq cont]
      )

      expect(filters).to contain_exactly(
        { field: "name", operator: "cont", value: "tower" }
      )
    end

    it "handles nil/blank input" do
      expect(described_class.translate(nil, field_names: field_names)).to eq([])
      expect(described_class.translate({}, field_names: field_names)).to eq([])
    end

    it "matches longer field names first" do
      fields = %w[status status_code]
      ransack = { "status_code_eq" => "A01" }

      filters = described_class.translate(ransack, field_names: fields)
      expect(filters.first[:field]).to eq("status_code")
    end
  end

  describe ".parse_ransack_key" do
    it "parses field_name and predicate" do
      sorted_fields = %w[name address].sort_by { |n| -n.length }

      field, op = described_class.parse_ransack_key("name_cont", sorted_fields)
      expect(field).to eq("name")
      expect(op).to eq("cont")
    end

    it "returns nil for unknown predicates" do
      result = described_class.parse_ransack_key("name_xyz", %w[name])
      expect(result).to be_nil
    end
  end
end
