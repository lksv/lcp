require "spec_helper"

RSpec.describe LcpRuby::ModelFactory::CallbackApplicator do
  before do
    LcpRuby::Types::BuiltInTypes.register_all!
    LcpRuby::Services::BuiltInTransforms.register_all!
    LcpRuby::Services::BuiltInDefaults.register_all!
  end

  after do
    ActiveRecord::Base.connection.drop_table(:items) if ActiveRecord::Base.connection.table_exists?(:items)
  end

  def build_full_model(model_hash)
    model_definition = LcpRuby::Metadata::ModelDefinition.from_hash(model_hash)
    LcpRuby::ModelFactory::SchemaManager.new(model_definition).ensure_table!
    builder = LcpRuby::ModelFactory::Builder.new(model_definition)
    builder.build
  end

  describe "Hash condition on field_change event" do
    let(:model_hash) do
      {
        "name" => "item",
        "fields" => [
          { "name" => "title", "type" => "string" },
          { "name" => "status", "type" => "string" }
        ],
        "events" => [
          {
            "name" => "on_status_change",
            "type" => "field_change",
            "field" => "status",
            "condition" => { "field" => "status", "operator" => "not_eq", "value" => "draft" }
          }
        ],
        "options" => { "timestamps" => false }
      }
    end

    it "fires event when Hash condition is met" do
      dispatched = []
      allow(LcpRuby::Events::Dispatcher).to receive(:dispatch) do |**args|
        dispatched << args
      end

      model_class = build_full_model(model_hash)
      record = model_class.create!(title: "Test", status: "draft")

      record.update!(status: "published")
      expect(dispatched.length).to eq(1)
      expect(dispatched.first[:event_name]).to eq("on_status_change")
    end

    it "does not fire event when Hash condition is not met" do
      dispatched = []
      allow(LcpRuby::Events::Dispatcher).to receive(:dispatch) do |**args|
        dispatched << args
      end

      model_class = build_full_model(model_hash)
      record = model_class.create!(title: "Test", status: "published")

      record.update!(status: "draft")
      expect(dispatched).to be_empty
    end
  end

  describe "no condition on field_change event" do
    let(:model_hash) do
      {
        "name" => "item",
        "fields" => [
          { "name" => "title", "type" => "string" },
          { "name" => "status", "type" => "string" }
        ],
        "events" => [
          {
            "name" => "on_status_change",
            "type" => "field_change",
            "field" => "status"
          }
        ],
        "options" => { "timestamps" => false }
      }
    end

    it "always fires event when no condition" do
      dispatched = []
      allow(LcpRuby::Events::Dispatcher).to receive(:dispatch) do |**args|
        dispatched << args
      end

      model_class = build_full_model(model_hash)
      record = model_class.create!(title: "Test", status: "draft")

      record.update!(status: "published")
      expect(dispatched.length).to eq(1)
    end
  end
end
