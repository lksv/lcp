module LcpRuby
  module Presenter
    # Resolves which associations to eager-load for a given presenter context.
    #
    # Auto-detects dependencies from presenter metadata (FK columns, association_list,
    # nested_fields) and supports manual overrides via includes/eager_load keys in
    # presenter YAML/DSL config.
    #
    # Usage:
    #   strategy = IncludesResolver.resolve(
    #     presenter_def: presenter,
    #     model_def: model,
    #     context: :index,
    #     sort_field: params[:sort],
    #     search_fields: ["company.name"]
    #   )
    #   scope = strategy.apply(scope)
    module IncludesResolver
      # @param presenter_def [PresenterDefinition]
      # @param model_def [ModelDefinition]
      # @param context [:index, :show, :form]
      # @param sort_field [String, nil] current sort field (may be dot-notation)
      # @param search_fields [Array<String>, nil] searchable fields (may include dot-notation)
      # @return [LoadingStrategy]
      def self.resolve(presenter_def:, model_def:, context:, sort_field: nil, search_fields: nil)
        collector = DependencyCollector.new
        collector.from_presenter(presenter_def, model_def, context)
        collector.from_sort(sort_field, model_def) if sort_field
        collector.from_search(search_fields, model_def) if search_fields&.any?

        config = case context
        when :index then presenter_def.index_config
        when :show  then presenter_def.show_config
        when :form  then presenter_def.form_config
        end
        collector.from_manual(config) if config

        StrategyResolver.resolve(collector.dependencies, model_def)
      end
    end
  end
end
