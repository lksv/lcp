require "spec_helper"

RSpec.describe LcpRuby::ModelFactory::AggregateApplicator do
  before do
    LcpRuby.reset!
    LcpRuby::Types::BuiltInTypes.register_all!
    LcpRuby::Services::BuiltInTransforms.register_all!
    LcpRuby::Services::BuiltInDefaults.register_all!
  end

  describe "#apply!" do
    it "does nothing for declarative aggregates" do
      model_def = LcpRuby::Metadata::ModelDefinition.from_hash({
        "name" => "test_agg_declarative",
        "fields" => [{ "name" => "name", "type" => "string" }],
        "associations" => [
          { "type" => "has_many", "name" => "items", "target_model" => "item", "foreign_key" => "test_agg_declarative_id" }
        ],
        "aggregates" => {
          "items_count" => { "function" => "count", "association" => "items" }
        }
      })

      model_class = Class.new(ActiveRecord::Base)
      applicator = described_class.new(model_class, model_def)
      expect { applicator.apply! }.not_to raise_error
    end

    it "raises for service aggregate with unregistered service" do
      model_def = LcpRuby::Metadata::ModelDefinition.from_hash({
        "name" => "test_agg_service",
        "fields" => [{ "name" => "name", "type" => "string" }],
        "aggregates" => {
          "health_score" => { "service" => "nonexistent_service", "type" => "integer" }
        }
      })

      model_class = Class.new(ActiveRecord::Base)
      applicator = described_class.new(model_class, model_def)

      expect { applicator.apply! }.to raise_error(
        LcpRuby::MetadataError,
        /service 'nonexistent_service' not found/
      )
    end

    it "succeeds when service is registered" do
      # Register a test service
      test_service = Class.new do
        def self.call(record, options: {})
          42
        end
      end
      LcpRuby::Services::Registry.register("aggregates", "test_health", test_service)

      model_def = LcpRuby::Metadata::ModelDefinition.from_hash({
        "name" => "test_agg_service_ok",
        "fields" => [{ "name" => "name", "type" => "string" }],
        "aggregates" => {
          "health_score" => { "service" => "test_health", "type" => "integer" }
        }
      })

      model_class = Class.new(ActiveRecord::Base)
      applicator = described_class.new(model_class, model_def)
      expect { applicator.apply! }.not_to raise_error
    end
  end
end
