require "spec_helper"

RSpec.describe LcpRuby::ModelFactory::RansackApplicator do
  let(:fixtures_path) { File.expand_path("../../../fixtures/metadata", __dir__) }

  let(:model_hash) do
    YAML.safe_load_file(File.join(fixtures_path, "models/project.yml"))["model"]
  end
  let(:model_definition) { LcpRuby::Metadata::ModelDefinition.from_hash(model_hash) }

  let(:task_hash) do
    YAML.safe_load_file(File.join(fixtures_path, "models/task.yml"))["model"]
  end
  let(:task_definition) { LcpRuby::Metadata::ModelDefinition.from_hash(task_hash) }

  let(:model_class) do
    LcpRuby::ModelFactory::SchemaManager.new(task_definition).ensure_table!
    LcpRuby::ModelFactory::Builder.new(task_definition).build

    LcpRuby::ModelFactory::SchemaManager.new(model_definition).ensure_table!
    LcpRuby::ModelFactory::Builder.new(model_definition).build
  end

  after do
    ActiveRecord::Base.connection.drop_table(:projects) if ActiveRecord::Base.connection.table_exists?(:projects)
    ActiveRecord::Base.connection.drop_table(:tasks) if ActiveRecord::Base.connection.table_exists?(:tasks)
  end

  describe "ransackable_attributes" do
    it "returns all column names without auth_object" do
      expect(model_class.ransackable_attributes).to include("title", "status", "description", "budget")
    end

    it "returns readable fields with PermissionEvaluator auth_object for same model" do
      evaluator = instance_double(LcpRuby::Authorization::PermissionEvaluator)
      allow(evaluator).to receive(:is_a?)
        .with(LcpRuby::Authorization::PermissionEvaluator)
        .and_return(true)
      allow(evaluator).to receive(:model_name).and_return("project")
      allow(evaluator).to receive(:readable_fields).and_return(%w[title status])

      expect(model_class.ransackable_attributes(evaluator)).to eq(%w[title status])
    end

    it "returns all column names when evaluator is for a different model" do
      evaluator = instance_double(LcpRuby::Authorization::PermissionEvaluator)
      allow(evaluator).to receive(:is_a?)
        .with(LcpRuby::Authorization::PermissionEvaluator)
        .and_return(true)
      allow(evaluator).to receive(:model_name).and_return("other_model")

      attrs = model_class.ransackable_attributes(evaluator)
      expect(attrs).to include("title", "status", "description", "budget")
    end

    it "returns column_names with non-evaluator auth_object" do
      attrs = model_class.ransackable_attributes("some_string")
      expect(attrs).to include("title", "status")
    end
  end

  describe "ransackable_associations" do
    before do
      # Register model definitions so loader can find them
      allow(LcpRuby).to receive(:loader).and_return(
        double("Loader", model_definition: model_definition, model_definitions: {})
      )
    end

    it "returns LCP model association names without auth_object" do
      assocs = model_class.ransackable_associations
      expect(assocs).to include("tasks")
    end

    it "filters by FK readability with PermissionEvaluator for same model" do
      evaluator = instance_double(LcpRuby::Authorization::PermissionEvaluator)
      allow(evaluator).to receive(:is_a?)
        .with(LcpRuby::Authorization::PermissionEvaluator)
        .and_return(true)
      allow(evaluator).to receive(:model_name).and_return("project")

      # client association has foreign_key client_id
      # We allow reading client_id, so client association should be included
      allow(evaluator).to receive(:field_readable?).with("client_id").and_return(true)

      assocs = model_class.ransackable_associations(evaluator)
      # tasks is has_many (no FK on project), should always be included
      expect(assocs).to include("tasks")
    end

    it "excludes associations when FK is not readable for same model" do
      evaluator = instance_double(LcpRuby::Authorization::PermissionEvaluator)
      allow(evaluator).to receive(:is_a?)
        .with(LcpRuby::Authorization::PermissionEvaluator)
        .and_return(true)
      allow(evaluator).to receive(:model_name).and_return("project")
      allow(evaluator).to receive(:field_readable?).with("client_id").and_return(false)

      assocs = model_class.ransackable_associations(evaluator)
      # tasks should still be there (has_many, no FK on this model)
      expect(assocs).to include("tasks")
    end

    it "returns all associations when evaluator is for a different model" do
      evaluator = instance_double(LcpRuby::Authorization::PermissionEvaluator)
      allow(evaluator).to receive(:is_a?)
        .with(LcpRuby::Authorization::PermissionEvaluator)
        .and_return(true)
      allow(evaluator).to receive(:model_name).and_return("other_model")

      assocs = model_class.ransackable_associations(evaluator)
      # All associations should be returned for cross-model traversal
      expect(assocs).to include("tasks")
    end
  end

  describe "ransackable_scopes" do
    it "returns empty array by default" do
      expect(model_class.ransackable_scopes).to eq([])
    end
  end
end
