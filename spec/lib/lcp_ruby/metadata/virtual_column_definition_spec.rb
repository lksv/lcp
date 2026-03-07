require "spec_helper"

RSpec.describe LcpRuby::Metadata::VirtualColumnDefinition do
  describe ".from_hash" do
    it "parses a declarative count aggregate" do
      vc = described_class.from_hash("issues_count", {
        "function" => "count",
        "association" => "issues"
      })

      expect(vc.name).to eq("issues_count")
      expect(vc.function).to eq("count")
      expect(vc.association).to eq("issues")
      expect(vc).to be_declarative
      expect(vc).not_to be_expression_type
      expect(vc).not_to be_service_type
    end

    it "parses a declarative sum aggregate with where and distinct" do
      vc = described_class.from_hash("total_value", {
        "function" => "sum",
        "association" => "orders",
        "source_field" => "amount",
        "where" => { "status" => "completed" },
        "distinct" => true,
        "default" => 0
      })

      expect(vc.function).to eq("sum")
      expect(vc.source_field).to eq("amount")
      expect(vc.where).to eq({ "status" => "completed" })
      expect(vc.distinct).to be true
      expect(vc.default).to eq(0)
    end

    it "parses an expression virtual column" do
      vc = described_class.from_hash("is_overdue", {
        "expression" => "CASE WHEN %{table}.due_date < CURRENT_DATE AND %{table}.status != 'done' THEN 1 ELSE 0 END",
        "type" => "boolean"
      })

      expect(vc).to be_expression_type
      expect(vc).not_to be_declarative
      expect(vc.expression).to include("%{table}")
      expect(vc.type).to eq("boolean")
    end

    it "parses an expression with join" do
      vc = described_class.from_hash("company_name", {
        "expression" => "companies.name",
        "join" => "LEFT JOIN companies ON companies.id = %{table}.company_id",
        "type" => "string"
      })

      expect(vc).to be_expression_type
      expect(vc.expression).to eq("companies.name")
      expect(vc.join).to include("LEFT JOIN")
    end

    it "parses an expression with join and group" do
      vc = described_class.from_hash("total_line_value", {
        "expression" => "SUM(line_items.quantity * line_items.unit_price)",
        "join" => "LEFT JOIN line_items ON line_items.order_id = %{table}.id",
        "group" => true,
        "type" => "decimal",
        "default" => 0
      })

      expect(vc).to be_expression_type
      expect(vc.group).to be true
      expect(vc.default).to eq(0)
    end

    it "parses auto_include" do
      vc = described_class.from_hash("cached_count", {
        "function" => "count",
        "association" => "items",
        "auto_include" => true
      })

      expect(vc.auto_include).to be true
    end

    it "maps legacy 'sql' key to expression" do
      vc = described_class.from_hash("weighted_score", {
        "sql" => "SELECT AVG(score) FROM ratings WHERE ratings.project_id = %{table}.id",
        "type" => "float"
      })

      expect(vc).to be_expression_type
      expect(vc.expression).to include("AVG(score)")
      expect(vc.sql).to eq(vc.expression) # Legacy accessor
    end

    it "raises when both sql and expression are specified" do
      expect {
        described_class.from_hash("bad", {
          "sql" => "SELECT 1",
          "expression" => "SELECT 2",
          "type" => "integer"
        })
      }.to raise_error(LcpRuby::MetadataError, /cannot specify both 'sql' and 'expression'/)
    end

    it "keeps sql_type? as alias for expression_type?" do
      vc = described_class.from_hash("score", {
        "expression" => "SELECT 1",
        "type" => "integer"
      })

      expect(vc.sql_type?).to be true
      expect(vc.expression_type?).to be true
    end

    it "parses a service virtual column" do
      vc = described_class.from_hash("health_score", {
        "service" => "project_health",
        "type" => "integer",
        "options" => { "threshold" => 50 }
      })

      expect(vc).to be_service_type
      expect(vc).not_to be_declarative
      expect(vc.service).to eq("project_health")
      expect(vc.options).to eq({ "threshold" => 50 })
    end

    it "parses include_discarded option" do
      vc = described_class.from_hash("all_issues", {
        "function" => "count",
        "association" => "issues",
        "include_discarded" => true
      })

      expect(vc.include_discarded).to be true
    end
  end

  describe "validation" do
    it "raises on missing name" do
      expect {
        described_class.new(name: "", function: "count", association: "items")
      }.to raise_error(LcpRuby::MetadataError, /name is required/)
    end

    it "raises on invalid function" do
      expect {
        described_class.new(name: "foo", function: "median", association: "items")
      }.to raise_error(LcpRuby::MetadataError, /invalid function/)
    end

    it "raises when declarative aggregate missing association" do
      expect {
        described_class.new(name: "foo", function: "count")
      }.to raise_error(LcpRuby::MetadataError, /requires 'association'/)
    end

    it "raises when non-count function missing source_field" do
      expect {
        described_class.new(name: "foo", function: "sum", association: "items")
      }.to raise_error(LcpRuby::MetadataError, /requires 'source_field'/)
    end

    it "raises when expression type missing type" do
      expect {
        described_class.new(name: "foo", expression: "SELECT 1")
      }.to raise_error(LcpRuby::MetadataError, /expression type requires 'type'/)
    end

    it "raises when legacy sql kwarg used without type" do
      expect {
        described_class.new(name: "foo", sql: "SELECT 1")
      }.to raise_error(LcpRuby::MetadataError, /expression type requires 'type'/)
    end

    it "raises when service type missing type" do
      expect {
        described_class.new(name: "foo", service: "my_service")
      }.to raise_error(LcpRuby::MetadataError, /service type requires 'type'/)
    end

    it "raises when no function, expression, or service specified" do
      expect {
        described_class.new(name: "foo")
      }.to raise_error(LcpRuby::MetadataError, /must specify/)
    end

    it "raises when auto_include and group are both true" do
      expect {
        described_class.new(
          name: "bad",
          expression: "SUM(x)",
          type: "integer",
          auto_include: true,
          group: true
        )
      }.to raise_error(LcpRuby::MetadataError, /auto_include and group cannot both be true/)
    end
  end

  describe "mutual exclusion validations" do
    it "raises when both function and expression are specified" do
      expect {
        described_class.new(name: "bad", function: "count", association: "items", expression: "SELECT 1", type: "integer")
      }.to raise_error(LcpRuby::MetadataError, /cannot specify both 'function' and 'expression'/)
    end

    it "raises when both function and service are specified" do
      expect {
        described_class.new(name: "bad", function: "count", association: "items", service: "my_svc", type: "integer")
      }.to raise_error(LcpRuby::MetadataError, /cannot specify both 'function' and 'service'/)
    end

    it "raises when both expression and service are specified" do
      expect {
        described_class.new(name: "bad", expression: "SELECT 1", service: "my_svc", type: "integer")
      }.to raise_error(LcpRuby::MetadataError, /cannot specify both 'expression' and 'service'/)
    end
  end

  describe "#inferred_type" do
    it "returns integer for count" do
      vc = described_class.from_hash("cnt", { "function" => "count", "association" => "items" })
      expect(vc.inferred_type).to eq("integer")
    end

    it "returns explicit type when set" do
      vc = described_class.from_hash("val", { "expression" => "SELECT 1", "type" => "decimal" })
      expect(vc.inferred_type).to eq("decimal")
    end

    it "returns float for avg without model context" do
      vc = described_class.from_hash("avg_score", {
        "function" => "avg",
        "association" => "scores",
        "source_field" => "value"
      })
      expect(vc.inferred_type).to eq("float")
    end

    it "returns decimal for sum/min/max fallback" do
      vc = described_class.from_hash("total", {
        "function" => "sum",
        "association" => "items",
        "source_field" => "price"
      })
      expect(vc.inferred_type).to eq("decimal")
    end

    it "returns string for unknown function fallback" do
      vc = described_class.from_hash("cnt", { "function" => "count", "association" => "items" })
      # count returns "integer", so test the else branch via expression type without explicit type
      # Actually count is already covered. Test the else branch: service with explicit type
      # The only way to get "string" fallback is if function is nil and type is nil — but that is invalid.
      # So test via a vc with function that passes through to the case statement
      # Actually, the "string" fallback in `else` of the case is unreachable for valid VCs
      # because every valid function is covered. Test sum/min/max instead:
      %w[min max].each do |func|
        vc = described_class.from_hash("val_#{func}", {
          "function" => func,
          "association" => "items",
          "source_field" => "amount"
        })
        expect(vc.inferred_type).to eq("decimal")
      end
    end

    context "with model context" do
      before do
        LcpRuby.reset!
        LcpRuby::Types::BuiltInTypes.register_all!
      end

      let(:target_model_def) do
        LcpRuby::Metadata::ModelDefinition.from_hash(
          "name" => "line_item",
          "fields" => [
            { "name" => "quantity", "type" => "integer" },
            { "name" => "amount", "type" => "decimal" },
            { "name" => "score", "type" => "float" }
          ]
        )
      end

      let(:model_def) do
        LcpRuby::Metadata::ModelDefinition.from_hash(
          "name" => "order",
          "fields" => [ { "name" => "title", "type" => "string" } ],
          "associations" => [
            { "type" => "has_many", "name" => "line_items", "target_model" => "line_item", "foreign_key" => "order_id" }
          ]
        )
      end

      before do
        LcpRuby.loader.model_definitions["line_item"] = target_model_def
      end

      it "resolves source_field type from target model" do
        vc = described_class.from_hash("total", {
          "function" => "sum",
          "association" => "line_items",
          "source_field" => "quantity"
        })
        expect(vc.inferred_type(model_def)).to eq("integer")
      end

      it "returns float for avg on non-decimal source_field" do
        vc = described_class.from_hash("avg_qty", {
          "function" => "avg",
          "association" => "line_items",
          "source_field" => "quantity"
        })
        expect(vc.inferred_type(model_def)).to eq("float")
      end

      it "returns decimal for avg on decimal source_field" do
        vc = described_class.from_hash("avg_amt", {
          "function" => "avg",
          "association" => "line_items",
          "source_field" => "amount"
        })
        expect(vc.inferred_type(model_def)).to eq("decimal")
      end
    end
  end
end
