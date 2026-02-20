require "ostruct"

module IntegrationHelper
  FIXTURES_BASE = File.expand_path("../fixtures/integration", __dir__)

  # Load metadata from a fixture subdirectory and build dynamic models/tables.
  # This is idempotent - tables are created if missing, updated if existing.
  def load_integration_metadata!(fixture_name)
    fixture_path = File.join(FIXTURES_BASE, fixture_name)
    raise "Integration fixture not found: #{fixture_path}" unless File.directory?(fixture_path)

    # Clean up previous state (reset! handles all registries + Dynamic constants)
    LcpRuby.reset!

    # Register built-in types, services, and renderers
    LcpRuby::Types::BuiltInTypes.register_all!
    LcpRuby::Services::BuiltInTransforms.register_all!
    LcpRuby::Services::BuiltInDefaults.register_all!
    LcpRuby::Display::RendererRegistry.register_built_ins!

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

    # Build built-in custom_field_definition model (unless user defined one)
    unless LcpRuby.registry.registered?("custom_field_definition")
      cfd_def = LcpRuby::CustomFields::BuiltInModel.model_definition
      schema_manager = LcpRuby::ModelFactory::SchemaManager.new(cfd_def)
      schema_manager.ensure_table!

      builder = LcpRuby::ModelFactory::Builder.new(cfd_def)
      model_class = builder.build

      LcpRuby.registry.register(cfd_def.name, model_class)
      loader.model_definitions["custom_field_definition"] = cfd_def
    end

    LcpRuby::CustomFields::Setup.apply!(loader)
    LcpRuby::Roles::Setup.apply!(loader)

    # Discover services from fixture path
    LcpRuby::ConditionServiceRegistry.discover!(fixture_path)
    LcpRuby::Services::Registry.discover!(fixture_path)

    # Discover actions and event handlers from fixture path
    LcpRuby::Actions::ActionRegistry.discover!(fixture_path)
    LcpRuby::Events::HandlerRegistry.discover!(fixture_path)
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

    # Also handle DSL model files (.rb)
    Dir[File.join(models_dir, "*.rb")].each do |file|
      model_name = File.basename(file, ".rb")
      table_name = model_name.pluralize
      connection.drop_table(table_name, if_exists: true)
    end

    # Drop built-in custom_field_definitions table if it was auto-created
    connection.drop_table("custom_field_definitions", if_exists: true)
  end

  # Stub the current_user method for integration tests
  def stub_current_user(role: [ "admin" ], id: 1)
    roles = Array(role)
    user = OpenStruct.new(id: id, lcp_role: roles, name: "Test User")
    allow_any_instance_of(LcpRuby::ApplicationController).to receive(:current_user).and_return(user)
    user
  end
end

RSpec.configure do |config|
  config.include IntegrationHelper, type: :request
end
