require "spec_helper"

RSpec.describe LcpRuby::Presenter::ColumnSet do
  let(:model_def) do
    LcpRuby::Metadata::ModelDefinition.from_hash(
      "name" => "deal",
      "fields" => [
        { "name" => "title", "type" => "string" },
        { "name" => "value", "type" => "decimal" }
      ],
      "associations" => [
        { "type" => "belongs_to", "name" => "company", "target_model" => "company", "foreign_key" => "company_id" },
        { "type" => "belongs_to", "name" => "contact", "target_model" => "contact", "foreign_key" => "contact_id" }
      ]
    )
  end

  let(:presenter_def) do
    LcpRuby::Metadata::PresenterDefinition.from_hash(
      "name" => "deal_admin",
      "model" => "deal",
      "index" => {
        "table_columns" => [
          { "field" => "title" },
          { "field" => "company_id" },
          { "field" => "value" }
        ]
      }
    )
  end

  let(:permission_def) do
    LcpRuby::Metadata::PermissionDefinition.from_hash(
      "model" => "deal",
      "default_role" => "admin",
      "roles" => {
        "admin" => { "crud" => %w[read create update delete], "fields" => { "readable" => %w[title company_id value], "writable" => %w[title company_id value] } },
        "restricted" => { "crud" => %w[read], "fields" => { "readable" => %w[title value], "writable" => [] } }
      }
    )
  end

  def make_user(role)
    double("User", lcp_role: role)
  end

  describe "#fk_association_map" do
    context "when user can see FK columns" do
      let(:evaluator) do
        LcpRuby::Authorization::PermissionEvaluator.new(permission_def, make_user("admin"), "deal")
      end

      let(:column_set) { described_class.new(presenter_def, evaluator) }

      it "returns FK associations for visible FK columns" do
        fk_map = column_set.fk_association_map(model_def)

        expect(fk_map.keys).to eq([ "company_id" ])
        expect(fk_map["company_id"].name).to eq("company")
      end

      it "excludes FK columns not in table_columns" do
        fk_map = column_set.fk_association_map(model_def)

        # contact_id is a belongs_to FK but not in table_columns
        expect(fk_map).not_to have_key("contact_id")
      end
    end

    context "when user cannot see FK columns" do
      let(:evaluator) do
        LcpRuby::Authorization::PermissionEvaluator.new(permission_def, make_user("restricted"), "deal")
      end

      let(:column_set) { described_class.new(presenter_def, evaluator) }

      it "returns empty map when FK columns are not readable" do
        fk_map = column_set.fk_association_map(model_def)

        # restricted role can only read title and value, not company_id
        expect(fk_map).to eq({})
      end
    end
  end
end
