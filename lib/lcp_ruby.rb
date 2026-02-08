require "lcp_ruby/version"
require "lcp_ruby/configuration"
require "lcp_ruby/dynamic"
require "lcp_ruby/current"
require "lcp_ruby/condition_evaluator"

# Metadata
require "lcp_ruby/metadata/validation_definition"
require "lcp_ruby/metadata/field_definition"
require "lcp_ruby/metadata/association_definition"
require "lcp_ruby/metadata/event_definition"
require "lcp_ruby/metadata/model_definition"
require "lcp_ruby/metadata/presenter_definition"
require "lcp_ruby/metadata/permission_definition"
require "lcp_ruby/metadata/loader"
require "lcp_ruby/metadata/configuration_validator"
require "lcp_ruby/metadata/erd_generator"

# Model Factory
require "lcp_ruby/model_factory/registry"
require "lcp_ruby/model_factory/schema_manager"
require "lcp_ruby/model_factory/validation_applicator"
require "lcp_ruby/model_factory/association_applicator"
require "lcp_ruby/model_factory/scope_applicator"
require "lcp_ruby/model_factory/callback_applicator"
require "lcp_ruby/model_factory/builder"

# Authorization
require "lcp_ruby/authorization/scope_builder"
require "lcp_ruby/authorization/permission_evaluator"
require "lcp_ruby/authorization/policy_factory"

# Events
require "lcp_ruby/events/handler_base"
require "lcp_ruby/events/handler_registry"
require "lcp_ruby/events/dispatcher"
require "lcp_ruby/events/async_handler_job"

# Actions
require "lcp_ruby/actions/base_action"
require "lcp_ruby/actions/action_registry"
require "lcp_ruby/actions/action_executor"

# Presenter
require "lcp_ruby/presenter/resolver"
require "lcp_ruby/presenter/column_set"
require "lcp_ruby/presenter/layout_builder"
require "lcp_ruby/presenter/action_set"

# Routing
require "lcp_ruby/routing/presenter_routes"

# Engine (must be last)
require "lcp_ruby/engine"

module LcpRuby
  class Error < StandardError; end
  class MetadataError < Error; end
  class SchemaError < Error; end

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

    def reset!
      @configuration = nil
      @loader = nil
      @registry = nil
    end
  end
end
