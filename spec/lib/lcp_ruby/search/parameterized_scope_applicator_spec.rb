require "spec_helper"

RSpec.describe LcpRuby::Search::ParameterizedScopeApplicator do
  let(:model_data) do
    {
      "name" => "task",
      "fields" => [
        { "name" => "title", "type" => "string" },
        { "name" => "status", "type" => "string" },
        { "name" => "created_at", "type" => "datetime" }
      ],
      "scopes" => [
        {
          "name" => "created_recently",
          "type" => "parameterized",
          "parameters" => [
            { "name" => "days", "type" => "integer", "default" => 7, "min" => 1, "max" => 365 }
          ]
        },
        {
          "name" => "by_category",
          "type" => "parameterized",
          "parameters" => [
            { "name" => "category", "type" => "enum", "values" => %w[electronics clothing food], "required" => true }
          ]
        },
        {
          "name" => "active",
          "type" => "parameterized",
          "parameters" => [
            { "name" => "include_pending", "type" => "boolean", "default" => false }
          ]
        }
      ]
    }
  end

  let(:model_definition) { LcpRuby::Metadata::ModelDefinition.from_hash(model_data) }
  let(:model_class) { double("ModelClass") }
  let(:scope) { double("Scope") }
  let(:evaluator) { double("Evaluator") }

  describe ".apply" do
    it "returns scope unchanged when scope_params is blank" do
      result = described_class.apply(scope, {}, model_class, model_definition, evaluator: evaluator)
      expect(result).to eq(scope)
    end

    it "invokes a parameterized scope with cast parameters" do
      filtered_scope = double("FilteredScope")
      allow(model_class).to receive(:respond_to?).with("filter_created_recently").and_return(false)
      allow(model_class).to receive(:respond_to?).with("created_recently").and_return(true)
      expect(scope).to receive(:send).with("created_recently", days: 30).and_return(filtered_scope)

      result = described_class.apply(
        scope,
        { "created_recently" => { "days" => "30" } },
        model_class, model_definition, evaluator: evaluator
      )
      expect(result).to eq(filtered_scope)
    end

    it "clamps numeric values to min/max" do
      filtered_scope = double("FilteredScope")
      allow(model_class).to receive(:respond_to?).with("filter_created_recently").and_return(false)
      allow(model_class).to receive(:respond_to?).with("created_recently").and_return(true)
      expect(scope).to receive(:send).with("created_recently", days: 365).and_return(filtered_scope)

      result = described_class.apply(
        scope,
        { "created_recently" => { "days" => "9999" } },
        model_class, model_definition, evaluator: evaluator
      )
      expect(result).to eq(filtered_scope)
    end

    it "prefers filter_* interceptor over direct scope" do
      filtered_scope = double("FilteredScope")
      allow(model_class).to receive(:respond_to?).with("filter_created_recently").and_return(true)
      expect(model_class).to receive(:send)
        .with("filter_created_recently", scope, { days: 30 }, evaluator)
        .and_return(filtered_scope)

      result = described_class.apply(
        scope,
        { "created_recently" => { "days" => "30" } },
        model_class, model_definition, evaluator: evaluator
      )
      expect(result).to eq(filtered_scope)
    end

    it "skips when required params are missing" do
      result = described_class.apply(
        scope,
        { "by_category" => {} },
        model_class, model_definition, evaluator: evaluator
      )
      expect(result).to eq(scope)
    end

    it "validates enum values" do
      filtered_scope = double("FilteredScope")
      allow(model_class).to receive(:respond_to?).with("filter_by_category").and_return(false)
      allow(model_class).to receive(:respond_to?).with("by_category").and_return(true)
      expect(scope).to receive(:send).with("by_category", category: "electronics").and_return(filtered_scope)

      result = described_class.apply(
        scope,
        { "by_category" => { "category" => "electronics" } },
        model_class, model_definition, evaluator: evaluator
      )
      expect(result).to eq(filtered_scope)
    end

    it "rejects invalid enum values" do
      result = described_class.apply(
        scope,
        { "by_category" => { "category" => "invalid_category" } },
        model_class, model_definition, evaluator: evaluator
      )
      # Category becomes nil, so it's treated as a missing required param
      expect(result).to eq(scope)
    end

    it "casts boolean parameters" do
      filtered_scope = double("FilteredScope")
      allow(model_class).to receive(:respond_to?).with("filter_active").and_return(false)
      allow(model_class).to receive(:respond_to?).with("active").and_return(true)
      expect(scope).to receive(:send).with("active", include_pending: true).and_return(filtered_scope)

      result = described_class.apply(
        scope,
        { "active" => { "include_pending" => "true" } },
        model_class, model_definition, evaluator: evaluator
      )
      expect(result).to eq(filtered_scope)
    end

    it "uses default values when params not provided" do
      filtered_scope = double("FilteredScope")
      allow(model_class).to receive(:respond_to?).with("filter_created_recently").and_return(false)
      allow(model_class).to receive(:respond_to?).with("created_recently").and_return(true)
      expect(scope).to receive(:send).with("created_recently", days: 7).and_return(filtered_scope)

      result = described_class.apply(
        scope,
        { "created_recently" => {} },
        model_class, model_definition, evaluator: evaluator
      )
      expect(result).to eq(filtered_scope)
    end

    it "ignores unknown scope names" do
      result = described_class.apply(
        scope,
        { "nonexistent_scope" => { "param" => "value" } },
        model_class, model_definition, evaluator: evaluator
      )
      expect(result).to eq(scope)
    end
  end
end
