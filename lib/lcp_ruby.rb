require "lcp_ruby/version"
require "lcp_ruby/hash_utils"
require "lcp_ruby/configuration"
require "lcp_ruby/association_options_builder"
require "lcp_ruby/dynamic"
require "lcp_ruby/current"
require "lcp_ruby/condition_evaluator"
require "lcp_ruby/condition_service_registry"

# Metadata
require "lcp_ruby/metadata/validation_definition"
require "lcp_ruby/metadata/field_definition"
require "lcp_ruby/metadata/association_definition"
require "lcp_ruby/metadata/event_definition"
require "lcp_ruby/metadata/display_template_definition"
require "lcp_ruby/metadata/model_definition"
require "lcp_ruby/metadata/presenter_definition"
require "lcp_ruby/metadata/permission_definition"
require "lcp_ruby/metadata/view_group_definition"
require "lcp_ruby/metadata/loader"
require "lcp_ruby/metadata/configuration_validator"
require "lcp_ruby/metadata/erd_generator"

# Types
require "lcp_ruby/types/type_definition"
require "lcp_ruby/types/type_registry"
require "lcp_ruby/types/transforms/base_transform"
require "lcp_ruby/types/transforms/strip"
require "lcp_ruby/types/transforms/downcase"
require "lcp_ruby/types/transforms/normalize_url"
require "lcp_ruby/types/transforms/normalize_phone"
require "lcp_ruby/types/built_in_types"

# DSL
require "lcp_ruby/dsl/field_builder"
require "lcp_ruby/dsl/type_builder"
require "lcp_ruby/dsl/model_builder"
require "lcp_ruby/dsl/presenter_builder"
require "lcp_ruby/dsl/view_group_builder"
require "lcp_ruby/dsl/dsl_loader"

# Services (unified registry)
require "lcp_ruby/services/registry"
require "lcp_ruby/services/built_in_defaults"
require "lcp_ruby/services/built_in_transforms"
require "lcp_ruby/services/checker"

# Model Factory
require "lcp_ruby/model_factory/registry"
require "lcp_ruby/model_factory/schema_manager"
require "lcp_ruby/model_factory/validation_applicator"
require "lcp_ruby/model_factory/association_applicator"
require "lcp_ruby/model_factory/scope_applicator"
require "lcp_ruby/model_factory/callback_applicator"
require "lcp_ruby/model_factory/transform_applicator"
require "lcp_ruby/model_factory/default_applicator"
require "lcp_ruby/model_factory/computed_applicator"
require "lcp_ruby/model_factory/attachment_applicator"
require "lcp_ruby/model_factory/builder"

# Authorization
require "lcp_ruby/authorization/scope_builder"
require "lcp_ruby/authorization/permission_evaluator"
require "lcp_ruby/authorization/policy_factory"
require "lcp_ruby/authorization/impersonated_user"

# Events
require "lcp_ruby/events/handler_base"
require "lcp_ruby/events/handler_registry"
require "lcp_ruby/events/dispatcher"
require "lcp_ruby/events/async_handler_job"

# Actions
require "lcp_ruby/actions/base_action"
require "lcp_ruby/actions/action_registry"
require "lcp_ruby/actions/action_executor"

# Display
require "lcp_ruby/display/base_renderer"
require "lcp_ruby/display/renderer_registry"

# Presenter
require "lcp_ruby/presenter/metadata_lookup"
require "lcp_ruby/presenter/resolver"
require "lcp_ruby/presenter/column_set"
require "lcp_ruby/presenter/layout_builder"
require "lcp_ruby/presenter/action_set"
require "lcp_ruby/presenter/includes_resolver"
require "lcp_ruby/presenter/includes_resolver/association_dependency"
require "lcp_ruby/presenter/includes_resolver/dependency_collector"
require "lcp_ruby/presenter/includes_resolver/strategy_resolver"
require "lcp_ruby/presenter/includes_resolver/loading_strategy"
require "lcp_ruby/presenter/field_value_resolver"

# Routing
require "lcp_ruby/routing/presenter_routes"

# Engine (must be last)
require "lcp_ruby/engine"

module LcpRuby
  class Error < StandardError; end
  class MetadataError < Error; end
  class SchemaError < Error; end
  class ServiceError < Error; end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def loader
      @loader ||= Metadata::Loader.new(configuration.metadata_path)
    end

    def registry
      @registry ||= ModelFactory::Registry.new
    end

    def define_model(name, &block)
      builder = Dsl::ModelBuilder.new(name)
      builder.instance_eval(&block)
      hash = builder.to_hash
      Metadata::ModelDefinition.from_hash(hash)
    end

    def define_type(name, &block)
      builder = Dsl::TypeBuilder.new(name)
      builder.instance_eval(&block)
      hash = builder.to_hash
      type_def = Types::TypeDefinition.from_hash(hash)
      Types::TypeRegistry.register(type_def.name, type_def)
      type_def
    end

    def define_presenter(name, &block)
      builder = Dsl::PresenterBuilder.new(name)
      builder.instance_eval(&block)
      hash = builder.to_hash
      Metadata::PresenterDefinition.from_hash(hash)
    end

    def check_services
      Services::Checker.new(loader.model_definitions).check
    end

    def check_services!
      result = check_services
      unless result.valid?
        raise ServiceError, "Missing service references:\n#{result.errors.map { |e| "  - #{e}" }.join("\n")}"
      end
      result
    end

    def json_column_type
      adapter = ActiveRecord::Base.connection.adapter_name.downcase
      adapter.include?("postgresql") ? :jsonb : :json
    end

    def reset!
      @configuration = nil
      @loader = nil
      @registry = nil
      Types::TypeRegistry.clear!
      ConditionServiceRegistry.clear!
      Events::HandlerRegistry.clear!
      Actions::ActionRegistry.clear!
      Display::RendererRegistry.clear!
      Authorization::PolicyFactory.clear!
      Services::Registry.clear!

      # Remove dynamic constants to avoid "already initialized" warnings
      Dynamic.constants.each do |const|
        Dynamic.send(:remove_const, const)
      end
    end
  end
end
