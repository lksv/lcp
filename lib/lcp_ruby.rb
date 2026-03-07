require "lcp_ruby/version"
require "lcp_ruby/hash_utils"
require "lcp_ruby/configuration"
require "lcp_ruby/association_options_builder"
require "lcp_ruby/dynamic"
require "lcp_ruby/current"
require "lcp_ruby/user_snapshot"
require "lcp_ruby/bulk_updater"
require "lcp_ruby/condition_evaluator"
require "lcp_ruby/condition_service_registry"
require "lcp_ruby/array_query"

# Metadata
require "lcp_ruby/metadata/validation_definition"
require "lcp_ruby/metadata/field_definition"
require "lcp_ruby/metadata/association_definition"
require "lcp_ruby/metadata/event_definition"
require "lcp_ruby/metadata/display_template_definition"
require "lcp_ruby/metadata/virtual_column_definition"
require "lcp_ruby/metadata/aggregate_definition"
require "lcp_ruby/metadata/model_definition"
require "lcp_ruby/metadata/presenter_definition"
require "lcp_ruby/metadata/permission_definition"
require "lcp_ruby/metadata/group_definition"
require "lcp_ruby/metadata/view_group_definition"
require "lcp_ruby/metadata/zone_definition"
require "lcp_ruby/metadata/page_definition"
require "lcp_ruby/metadata/menu_item"
require "lcp_ruby/metadata/menu_definition"
require "lcp_ruby/metadata/loader"
require "lcp_ruby/metadata/contract_result"
require "lcp_ruby/metadata/schema_validator"
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
require "lcp_ruby/dsl/condition_builder"
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
require "lcp_ruby/services/accessors/json_field"
require "lcp_ruby/services/built_in_accessors"
require "lcp_ruby/services/checker"

# Search
require "lcp_ruby/search/param_sanitizer"
require "lcp_ruby/search/operator_registry"
require "lcp_ruby/search/quick_search"
require "lcp_ruby/search/filter_param_builder"
require "lcp_ruby/search/custom_filter_interceptor"
require "lcp_ruby/search/filter_metadata_builder"
require "lcp_ruby/search/custom_field_filter"
require "lcp_ruby/search/query_language_parser"
require "lcp_ruby/search/query_language_serializer"
require "lcp_ruby/search/parameterized_scope_applicator"

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
require "lcp_ruby/model_factory/service_accessor_applicator"
require "lcp_ruby/model_factory/attachment_applicator"
require "lcp_ruby/model_factory/positioning_applicator"
require "lcp_ruby/model_factory/userstamps_applicator"
require "lcp_ruby/model_factory/soft_delete_applicator"
require "lcp_ruby/model_factory/tree_applicator"
require "lcp_ruby/model_factory/auditing_applicator"
require "lcp_ruby/model_factory/ransack_applicator"
require "lcp_ruby/model_factory/virtual_column_applicator"
require "lcp_ruby/model_factory/aggregate_applicator"
require "lcp_ruby/model_factory/array_type"
require "lcp_ruby/model_factory/array_type_applicator"
require "lcp_ruby/model_factory/sequence_applicator"
require "lcp_ruby/model_factory/builder"
require "lcp_ruby/model_factory/api_builder"
require "lcp_ruby/model_factory/api_association_applicator"

# Virtual Columns
require "lcp_ruby/virtual_columns"
require "lcp_ruby/virtual_columns/builder"
require "lcp_ruby/virtual_columns/collector"

# Aggregates (backward compatibility alias)
require "lcp_ruby/aggregates/query_builder"

# JSON Item Wrapper (for model-backed JSON field items)
require "lcp_ruby/json_item_wrapper"

# Custom Fields
require "lcp_ruby/custom_fields"
require "lcp_ruby/custom_fields/registry"
require "lcp_ruby/custom_fields/applicator"
require "lcp_ruby/custom_fields/query"
require "lcp_ruby/custom_fields/utils"
require "lcp_ruby/custom_fields/definition_change_handler"
require "lcp_ruby/custom_fields/contract_validator"
require "lcp_ruby/custom_fields/setup"

# Roles
require "lcp_ruby/roles/registry"
require "lcp_ruby/roles/contract_validator"
require "lcp_ruby/roles/change_handler"
require "lcp_ruby/roles/setup"

# Permissions (DB-backed permission source)
require "lcp_ruby/permissions/registry"
require "lcp_ruby/permissions/contract_validator"
require "lcp_ruby/permissions/change_handler"
require "lcp_ruby/permissions/definition_validator"
require "lcp_ruby/permissions/source_resolver"
require "lcp_ruby/permissions/setup"

# Sequences
require "lcp_ruby/sequences/sequence_manager"

# Auditing
require "lcp_ruby/auditing/registry"
require "lcp_ruby/auditing/contract_validator"
require "lcp_ruby/auditing/audit_writer"
require "lcp_ruby/auditing/setup"

# Groups
require "lcp_ruby/groups/contract"
require "lcp_ruby/groups/registry"
require "lcp_ruby/groups/yaml_loader"
require "lcp_ruby/groups/model_loader"
require "lcp_ruby/groups/host_loader"
require "lcp_ruby/groups/contract_validator"
require "lcp_ruby/groups/change_handler"
require "lcp_ruby/groups/setup"

# Saved Filters
require "lcp_ruby/saved_filters/registry"
require "lcp_ruby/saved_filters/contract_validator"
require "lcp_ruby/saved_filters/change_handler"
require "lcp_ruby/saved_filters/resolver"
require "lcp_ruby/saved_filters/stale_field_validator"
require "lcp_ruby/saved_filters/setup"

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
require "lcp_ruby/display/renderers"

# View Slots
require "lcp_ruby/view_slots/slot_component"
require "lcp_ruby/view_slots/slot_context"
require "lcp_ruby/view_slots/registry"

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
require "lcp_ruby/presenter/breadcrumb_builder"
require "lcp_ruby/presenter/breadcrumb_path_helper"

# Widgets
require "lcp_ruby/widgets/data_resolver"
require "lcp_ruby/widgets/presenter_zone_resolver"

# Pages
require "lcp_ruby/pages/resolver"

# Routing
require "lcp_ruby/routing/presenter_routes"

# Authentication
require "lcp_ruby/authentication"

# Engine (must be last)
require "lcp_ruby/engine"

module LcpRuby
  class Error < StandardError; end
  class MetadataError < Error; end
  class SchemaError < Error; end
  class ServiceError < Error; end
  class ConditionError < Error; end

  # Search Result (requires LcpRuby module to exist)
  require "lcp_ruby/search_result"

  # Data Source (requires LcpRuby::Error to exist)
  require "lcp_ruby/data_source/base"
  require "lcp_ruby/data_source/api_error_placeholder"
  require "lcp_ruby/data_source/rest_json"
  require "lcp_ruby/data_source/host"
  require "lcp_ruby/data_source/cached_wrapper"
  require "lcp_ruby/data_source/resilient_wrapper"
  require "lcp_ruby/data_source/registry"
  require "lcp_ruby/data_source/api_model_concern"
  require "lcp_ruby/data_source/api_filter_translator"
  require "lcp_ruby/data_source/api_preloader"
  require "lcp_ruby/data_source/setup"

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

    def postgresql?
      ActiveRecord::Base.connection.adapter_name.downcase.include?("postgresql")
    end

    def json_column_type
      postgresql? ? :jsonb : :json
    end

    # Returns true when the process was invoked via `rails generate`.
    # Used by Setup modules to downgrade hard errors to warnings so
    # generators can boot the app and create the missing files
    # (chicken-and-egg problem).
    def generator_context?
      defined?(Rails::Command) &&
        $PROGRAM_NAME.end_with?("/rails") &&
        ARGV.first&.match?(/\Ag(enerate)?\z/)
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
      CustomFields::Registry.clear!
      Roles::Registry.clear!
      Permissions::Registry.clear!
      Groups::Registry.clear!
      Auditing::Registry.clear!
      Auditing::AuditWriter.clear_cache!
      SavedFilters::Registry.clear!
      DataSource::Registry.clear!
      ViewSlots::Registry.clear!
      Pages::Resolver.clear!

      # Remove dynamic constants to avoid "already initialized" warnings
      Dynamic.constants.each do |const|
        Dynamic.send(:remove_const, const)
      end
    end
  end
end
