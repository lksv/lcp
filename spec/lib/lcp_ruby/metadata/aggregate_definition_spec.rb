require "spec_helper"

RSpec.describe LcpRuby::Metadata::AggregateDefinition do
  describe ".from_hash" do
    it "parses a declarative count aggregate" do
      agg = described_class.from_hash("issues_count", {
        "function" => "count",
        "association" => "issues"
      })

      expect(agg.name).to eq("issues_count")
      expect(agg.function).to eq("count")
      expect(agg.association).to eq("issues")
      expect(agg).to be_declarative
      expect(agg).not_to be_sql_type
      expect(agg).not_to be_service_type
    end

    it "parses a declarative sum aggregate with where and distinct" do
      agg = described_class.from_hash("total_value", {
        "function" => "sum",
        "association" => "orders",
        "source_field" => "amount",
        "where" => { "status" => "completed" },
        "distinct" => true,
        "default" => 0
      })

      expect(agg.function).to eq("sum")
      expect(agg.source_field).to eq("amount")
      expect(agg.where).to eq({ "status" => "completed" })
      expect(agg.distinct).to be true
      expect(agg.default).to eq(0)
    end

    it "parses a SQL aggregate" do
      agg = described_class.from_hash("weighted_score", {
        "sql" => "SELECT AVG(score) FROM ratings WHERE ratings.project_id = %{table}.id",
        "type" => "float"
      })

      expect(agg).to be_sql_type
      expect(agg).not_to be_declarative
      expect(agg.sql).to include("%{table}")
      expect(agg.type).to eq("float")
    end

    it "parses a service aggregate" do
      agg = described_class.from_hash("health_score", {
        "service" => "project_health",
        "type" => "integer",
        "options" => { "threshold" => 50 }
      })

      expect(agg).to be_service_type
      expect(agg).not_to be_declarative
      expect(agg.service).to eq("project_health")
      expect(agg.options).to eq({ "threshold" => 50 })
    end

    it "parses include_discarded option" do
      agg = described_class.from_hash("all_issues", {
        "function" => "count",
        "association" => "issues",
        "include_discarded" => true
      })

      expect(agg.include_discarded).to be true
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

    it "raises when SQL aggregate missing type" do
      expect {
        described_class.new(name: "foo", sql: "SELECT 1")
      }.to raise_error(LcpRuby::MetadataError, /requires 'type'/)
    end

    it "raises when service aggregate missing type" do
      expect {
        described_class.new(name: "foo", service: "my_service")
      }.to raise_error(LcpRuby::MetadataError, /requires 'type'/)
    end

    it "raises when no function, sql, or service specified" do
      expect {
        described_class.new(name: "foo")
      }.to raise_error(LcpRuby::MetadataError, /must specify/)
    end
  end

  describe "#inferred_type" do
    it "returns integer for count" do
      agg = described_class.from_hash("cnt", { "function" => "count", "association" => "items" })
      expect(agg.inferred_type).to eq("integer")
    end

    it "returns explicit type when set" do
      agg = described_class.from_hash("val", { "sql" => "SELECT 1", "type" => "decimal" })
      expect(agg.inferred_type).to eq("decimal")
    end

    it "returns float for avg without model context" do
      agg = described_class.from_hash("avg_score", {
        "function" => "avg",
        "association" => "scores",
        "source_field" => "value"
      })
      expect(agg.inferred_type).to eq("float")
    end
  end
end
