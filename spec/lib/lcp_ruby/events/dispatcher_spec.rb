require "spec_helper"

RSpec.describe LcpRuby::Events::Dispatcher do
  let(:fixtures_path) { File.expand_path("../../../fixtures/metadata", __dir__) }

  before do
    model_hash = YAML.safe_load_file(File.join(fixtures_path, "models/project.yml"))["model"]
    model_def = LcpRuby::Metadata::ModelDefinition.from_hash(model_hash)

    LcpRuby::ModelFactory::SchemaManager.new(model_def).ensure_table!
    @model_class = LcpRuby::ModelFactory::Builder.new(model_def).build
    LcpRuby.registry.register("project", @model_class)
  end

  after do
    ActiveRecord::Base.connection.drop_table(:projects) if ActiveRecord::Base.connection.table_exists?(:projects)
  end

  describe ".dispatch" do
    it "dispatches to registered handlers" do
      handler_called = false

      test_handler = Class.new(LcpRuby::Events::HandlerBase) do
        define_method(:call) { handler_called = true }
        define_singleton_method(:handles_event) { "after_create" }
      end

      LcpRuby::Events::HandlerRegistry.register("project", "after_create", test_handler)

      record = @model_class.create!(title: "Test Project")
      described_class.dispatch(event_name: "after_create", record: record)

      expect(handler_called).to be true
    end

    it "does nothing when no handlers registered" do
      record = @model_class.create!(title: "Test Project")

      expect {
        described_class.dispatch(event_name: "after_create", record: record)
      }.not_to raise_error
    end

    it "passes changes to handler" do
      received_changes = nil

      test_handler = Class.new(LcpRuby::Events::HandlerBase) do
        define_method(:call) { received_changes = changes }
        define_singleton_method(:handles_event) { "after_update" }
      end

      LcpRuby::Events::HandlerRegistry.register("project", "after_update", test_handler)

      record = @model_class.create!(title: "Before")
      changes = { "title" => [ "Before", "After" ] }
      described_class.dispatch(event_name: "after_update", record: record, changes: changes)

      expect(received_changes).to eq("title" => [ "Before", "After" ])
    end
  end
end
