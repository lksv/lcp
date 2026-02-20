require "spec_helper"

RSpec.describe LcpRuby::Services::Checker do
  before do
    LcpRuby::Types::BuiltInTypes.register_all!
    LcpRuby::Services::BuiltInTransforms.register_all!
    LcpRuby::Services::BuiltInDefaults.register_all!
  end

  def build_model_definitions(models_array)
    models_array.each_with_object({}) do |hash, acc|
      model_def = LcpRuby::Metadata::ModelDefinition.from_hash(hash)
      acc[model_def.name] = model_def
    end
  end

  describe "#check" do
    it "returns valid result when no services are referenced" do
      definitions = build_model_definitions([
        {
          "name" => "task",
          "fields" => [
            { "name" => "title", "type" => "string" }
          ]
        }
      ])

      result = described_class.new(definitions).check
      expect(result).to be_valid
      expect(result.errors).to be_empty
    end

    it "returns valid result when all referenced default services exist" do
      definitions = build_model_definitions([
        {
          "name" => "task",
          "fields" => [
            { "name" => "title", "type" => "string" },
            { "name" => "created_on", "type" => "date", "default" => "current_date" }
          ]
        }
      ])

      result = described_class.new(definitions).check
      expect(result).to be_valid
    end

    it "returns valid result for hash-style default service references" do
      LcpRuby::Services::Registry.register("defaults", "custom_default", ->(_r, _f) { "val" })

      definitions = build_model_definitions([
        {
          "name" => "task",
          "fields" => [
            { "name" => "title", "type" => "string" },
            { "name" => "ref_code", "type" => "string", "default" => { "service" => "custom_default" } }
          ]
        }
      ])

      result = described_class.new(definitions).check
      expect(result).to be_valid
    end

    it "reports error for missing hash-style default service" do
      definitions = build_model_definitions([
        {
          "name" => "task",
          "fields" => [
            { "name" => "title", "type" => "string" },
            { "name" => "ref_code", "type" => "string", "default" => { "service" => "nonexistent_default" } }
          ]
        }
      ])

      result = described_class.new(definitions).check
      expect(result).not_to be_valid
      expect(result.errors.first).to include("nonexistent_default")
      expect(result.errors.first).to include("task")
      expect(result.errors.first).to include("ref_code")
    end

    it "returns valid result when referenced computed service exists" do
      LcpRuby::Services::Registry.register("computed", "full_name", ->(_r, _f) { "val" })

      definitions = build_model_definitions([
        {
          "name" => "contact",
          "fields" => [
            { "name" => "first_name", "type" => "string" },
            { "name" => "display_name", "type" => "string", "computed" => { "service" => "full_name" } }
          ]
        }
      ])

      result = described_class.new(definitions).check
      expect(result).to be_valid
    end

    it "reports error for missing computed service" do
      definitions = build_model_definitions([
        {
          "name" => "contact",
          "fields" => [
            { "name" => "first_name", "type" => "string" },
            { "name" => "display_name", "type" => "string", "computed" => { "service" => "missing_computed" } }
          ]
        }
      ])

      result = described_class.new(definitions).check
      expect(result).not_to be_valid
      expect(result.errors.first).to include("missing_computed")
      expect(result.errors.first).to include("computed service")
    end

    it "returns valid result for built-in transforms" do
      definitions = build_model_definitions([
        {
          "name" => "task",
          "fields" => [
            { "name" => "email", "type" => "string", "transforms" => [ "strip", "downcase" ] }
          ]
        }
      ])

      result = described_class.new(definitions).check
      expect(result).to be_valid
    end

    it "reports error for missing transform" do
      definitions = build_model_definitions([
        {
          "name" => "task",
          "fields" => [
            { "name" => "title", "type" => "string", "transforms" => [ "nonexistent_transform" ] }
          ]
        }
      ])

      result = described_class.new(definitions).check
      expect(result).not_to be_valid
      expect(result.errors.first).to include("nonexistent_transform")
      expect(result.errors.first).to include("transform")
    end

    it "reports error for missing field-level validator service" do
      definitions = build_model_definitions([
        {
          "name" => "task",
          "fields" => [
            {
              "name" => "description",
              "type" => "text",
              "validations" => [
                { "type" => "service", "service" => "missing_validator" }
              ]
            }
          ]
        }
      ])

      result = described_class.new(definitions).check
      expect(result).not_to be_valid
      expect(result.errors.first).to include("missing_validator")
      expect(result.errors.first).to include("field 'description'")
    end

    it "returns valid result when field-level validator service exists" do
      LcpRuby::Services::Registry.register("validators", "desc_checker", Class.new { def self.call(r, **o); end })

      definitions = build_model_definitions([
        {
          "name" => "task",
          "fields" => [
            {
              "name" => "description",
              "type" => "text",
              "validations" => [
                { "type" => "service", "service" => "desc_checker" }
              ]
            }
          ]
        }
      ])

      result = described_class.new(definitions).check
      expect(result).to be_valid
    end

    it "reports error for missing model-level validator service" do
      definitions = build_model_definitions([
        {
          "name" => "task",
          "fields" => [
            { "name" => "title", "type" => "string" }
          ],
          "validations" => [
            { "type" => "service", "service" => "missing_model_validator" }
          ]
        }
      ])

      result = described_class.new(definitions).check
      expect(result).not_to be_valid
      expect(result.errors.first).to include("missing_model_validator")
      expect(result.errors.first).to include("model-level")
    end

    it "returns valid result when accessor service exists" do
      LcpRuby::Services::BuiltInAccessors.register_all!

      definitions = build_model_definitions([
        {
          "name" => "order",
          "fields" => [
            { "name" => "metadata", "type" => "json" },
            { "name" => "color", "type" => "string",
              "source" => { "service" => "json_field", "options" => { "column" => "metadata", "key" => "color" } } }
          ]
        }
      ])

      result = described_class.new(definitions).check
      expect(result).to be_valid
    end

    it "reports error for missing accessor service" do
      definitions = build_model_definitions([
        {
          "name" => "order",
          "fields" => [
            { "name" => "metadata", "type" => "json" },
            { "name" => "color", "type" => "string",
              "source" => { "service" => "missing_accessor", "options" => {} } }
          ]
        }
      ])

      result = described_class.new(definitions).check
      expect(result).not_to be_valid
      expect(result.errors.first).to include("missing_accessor")
      expect(result.errors.first).to include("accessor service")
    end

    it "skips external fields (no service to check)" do
      definitions = build_model_definitions([
        {
          "name" => "order",
          "fields" => [
            { "name" => "title", "type" => "string" },
            { "name" => "stock", "type" => "integer", "source" => "external" }
          ]
        }
      ])

      result = described_class.new(definitions).check
      expect(result).to be_valid
    end

    it "collects multiple errors across models and fields" do
      definitions = build_model_definitions([
        {
          "name" => "task",
          "fields" => [
            { "name" => "title", "type" => "string", "default" => { "service" => "missing_a" } },
            { "name" => "body", "type" => "text", "transforms" => [ "missing_b" ] }
          ]
        }
      ])

      result = described_class.new(definitions).check
      expect(result).not_to be_valid
      expect(result.errors.size).to eq(2)
    end

    it "has a meaningful to_s for valid results" do
      definitions = build_model_definitions([
        { "name" => "task", "fields" => [ { "name" => "title", "type" => "string" } ] }
      ])

      result = described_class.new(definitions).check
      expect(result.to_s).to eq("All service references are valid.")
    end

    it "has a meaningful to_s for invalid results" do
      definitions = build_model_definitions([
        {
          "name" => "task",
          "fields" => [
            { "name" => "title", "type" => "string", "default" => { "service" => "gone" } }
          ]
        }
      ])

      result = described_class.new(definitions).check
      expect(result.to_s).to include("Service reference errors")
      expect(result.to_s).to include("[ERROR]")
    end
  end

  describe "LcpRuby.check_services" do
    it "returns a check result" do
      # Ensure loader has model definitions loaded
      loader = LcpRuby::Metadata::Loader.new(
        File.expand_path("../../../fixtures/integration/todo", __dir__)
      )
      loader.load_all
      allow(LcpRuby).to receive(:loader).and_return(loader)

      result = LcpRuby.check_services
      expect(result).to respond_to(:valid?)
      expect(result).to respond_to(:errors)
    end
  end

  describe "LcpRuby.check_services!" do
    it "raises ServiceError when services are missing" do
      definitions = build_model_definitions([
        {
          "name" => "task",
          "fields" => [
            { "name" => "title", "type" => "string", "default" => { "service" => "nonexistent" } }
          ]
        }
      ])

      loader = instance_double(LcpRuby::Metadata::Loader, model_definitions: definitions)
      allow(LcpRuby).to receive(:loader).and_return(loader)

      expect { LcpRuby.check_services! }.to raise_error(LcpRuby::ServiceError, /nonexistent/)
    end

    it "does not raise when all services are valid" do
      definitions = build_model_definitions([
        { "name" => "task", "fields" => [ { "name" => "title", "type" => "string" } ] }
      ])

      loader = instance_double(LcpRuby::Metadata::Loader, model_definitions: definitions)
      allow(LcpRuby).to receive(:loader).and_return(loader)

      expect { LcpRuby.check_services! }.not_to raise_error
    end
  end
end
