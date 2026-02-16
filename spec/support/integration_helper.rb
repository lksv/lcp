require "ostruct"

module IntegrationHelper
  FIXTURES_BASE = File.expand_path("../fixtures/integration", __dir__)

  # Load metadata from a fixture subdirectory and build dynamic models/tables.
  # This is idempotent - tables are created if missing, updated if existing.
  def load_integration_metadata!(fixture_name)
    fixture_path = File.join(FIXTURES_BASE, fixture_name)
    raise "Integration fixture not found: #{fixture_path}" unless File.directory?(fixture_path)

    # Clean up previous state
    LcpRuby.reset!
    LcpRuby::Events::HandlerRegistry.clear!
    LcpRuby::Actions::ActionRegistry.clear!
    LcpRuby::Authorization::PolicyFactory.clear!

    # Remove dynamic constants to avoid "already initialized" warnings
    LcpRuby::Dynamic.constants.each do |const|
      LcpRuby::Dynamic.send(:remove_const, const)
    end

    # Register built-in types and services
    LcpRuby::Types::BuiltInServices.register_all!
    LcpRuby::Types::BuiltInTypes.register_all!

    # Configure and load
    LcpRuby.configuration.metadata_path = fixture_path
    LcpRuby.configuration.auto_migrate = true

    loader = LcpRuby.loader
    loader.load_all

    loader.model_definitions.each_value do |model_def|
      schema_manager = LcpRuby::ModelFactory::SchemaManager.new(model_def)
      schema_manager.ensure_table!

      builder = LcpRuby::ModelFactory::Builder.new(model_def)
      model_class = builder.build

      LcpRuby.registry.register(model_def.name, model_class)
    end
  end

  # Drop tables for the given fixture's models
  def teardown_integration_tables!(fixture_name)
    fixture_path = File.join(FIXTURES_BASE, fixture_name)
    return unless File.directory?(fixture_path)

    models_dir = File.join(fixture_path, "models")
    return unless File.directory?(models_dir)

    connection = ActiveRecord::Base.connection

    Dir[File.join(models_dir, "*.yml")].each do |file|
      data = YAML.safe_load_file(file, permitted_classes: [ Symbol, Regexp ])
      next unless data && data["model"]

      model_name = data["model"]["name"]
      table_name = data["model"]["table_name"] || model_name.pluralize
      connection.drop_table(table_name, if_exists: true)
    end
  end

  # Stub the current_user method for integration tests
  def stub_current_user(role: "admin", id: 1)
    user = OpenStruct.new(id: id, lcp_role: role, name: "Test User")
    allow_any_instance_of(LcpRuby::ApplicationController).to receive(:current_user).and_return(user)
    user
  end
end

RSpec.configure do |config|
  config.include IntegrationHelper, type: :request
end
