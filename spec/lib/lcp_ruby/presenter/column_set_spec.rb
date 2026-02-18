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
    double("User", lcp_role: Array(role))
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

  describe "dot-path and template column visibility" do
    let(:company_model_def) do
      LcpRuby::Metadata::ModelDefinition.from_hash(
        "name" => "company",
        "fields" => [
          { "name" => "name", "type" => "string" },
          { "name" => "industry", "type" => "string" }
        ]
      )
    end

    let(:company_perm_def) do
      LcpRuby::Metadata::PermissionDefinition.from_hash(
        "model" => "company",
        "default_role" => "admin",
        "roles" => {
          "admin" => { "crud" => %w[read], "fields" => { "readable" => "all", "writable" => "all" } },
          "restricted" => { "crud" => %w[read], "fields" => { "readable" => %w[name], "writable" => [] } }
        }
      )
    end

    before do
      allow(LcpRuby).to receive(:loader).and_return(
        double("Loader").tap do |loader|
          allow(loader).to receive(:model_definition) do |name|
            case name.to_s
            when "deal" then model_def
            when "company" then company_model_def
            else raise LcpRuby::MetadataError, "Model '#{name}' not found"
            end
          end
          allow(loader).to receive(:permission_definition) do |name|
            case name.to_s
            when "company" then company_perm_def
            else permission_def
            end
          end
        end
      )
    end

    context "dot-path columns" do
      let(:dot_path_presenter) do
        LcpRuby::Metadata::PresenterDefinition.from_hash(
          "name" => "deal_admin",
          "model" => "deal",
          "index" => {
            "table_columns" => [
              { "field" => "title" },
              { "field" => "company.name" },
              { "field" => "company.industry" }
            ]
          }
        )
      end

      it "shows dot-path column when target field is readable" do
        evaluator = LcpRuby::Authorization::PermissionEvaluator.new(permission_def, make_user("admin"), "deal")
        column_set = described_class.new(dot_path_presenter, evaluator)

        columns = column_set.visible_table_columns
        fields = columns.map { |c| c["field"] }
        expect(fields).to include("company.name")
      end

      it "hides dot-path column when target field is not readable" do
        evaluator = LcpRuby::Authorization::PermissionEvaluator.new(permission_def, make_user("restricted"), "deal")
        column_set = described_class.new(dot_path_presenter, evaluator)

        columns = column_set.visible_table_columns
        fields = columns.map { |c| c["field"] }
        # restricted user on company can only read 'name', not 'industry'
        expect(fields).to include("company.name")
        expect(fields).not_to include("company.industry")
      end
    end

    context "template columns" do
      let(:template_presenter) do
        LcpRuby::Metadata::PresenterDefinition.from_hash(
          "name" => "deal_admin",
          "model" => "deal",
          "index" => {
            "table_columns" => [
              { "field" => "{company.name}: {title}" },
              { "field" => "{company.industry}" }
            ]
          }
        )
      end

      it "shows template column when all refs are readable" do
        evaluator = LcpRuby::Authorization::PermissionEvaluator.new(permission_def, make_user("admin"), "deal")
        column_set = described_class.new(template_presenter, evaluator)

        columns = column_set.visible_table_columns
        expect(columns.size).to eq(2)
      end

      it "hides template column when any ref is not readable" do
        evaluator = LcpRuby::Authorization::PermissionEvaluator.new(permission_def, make_user("restricted"), "deal")
        column_set = described_class.new(template_presenter, evaluator)

        columns = column_set.visible_table_columns
        fields = columns.map { |c| c["field"] }
        # restricted can read company.name + title => first template visible
        expect(fields).to include("{company.name}: {title}")
        # restricted cannot read company.industry => second template hidden
        expect(fields).not_to include("{company.industry}")
      end
    end
  end
end
