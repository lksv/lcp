module LcpRuby
  class ResourcesController < ApplicationController
    before_action :set_record, only: [ :show, :edit, :update, :destroy, :evaluate_conditions ]

    def index
      authorize @model_class
      scope = policy_scope(@model_class)
      scope = apply_search(scope)
      scope = apply_sort(scope)

      @summaries = compute_summaries(scope) if summary_columns_present?

      strategy = resolve_loading_strategy(:index)
      scope = strategy.apply(scope)
      scope = scope.strict_loading if LcpRuby.configuration.strict_loading_enabled?

      @records = scope.page(params[:page]).per(current_presenter.per_page)

      @column_set = Presenter::ColumnSet.new(current_presenter, current_evaluator)
      @fk_map = @column_set.fk_association_map(current_model_definition)
      @action_set = Presenter::ActionSet.new(current_presenter, current_evaluator)
    end

    def show
      authorize @record
      preload_associations(@record, :show)
      @record.strict_loading! if LcpRuby.configuration.strict_loading_enabled?
      @layout_builder = Presenter::LayoutBuilder.new(current_presenter, current_model_definition)
      @column_set = Presenter::ColumnSet.new(current_presenter, current_evaluator)
      @action_set = Presenter::ActionSet.new(current_presenter, current_evaluator)
    end

    def new
      @record = @model_class.new
      authorize @record
      build_nested_records(@record)
      @layout_builder = Presenter::LayoutBuilder.new(current_presenter, current_model_definition)
    end

    def create
      @record = @model_class.new(permitted_params)
      authorize @record

      if @record.save
        redirect_to resource_path(@record), notice: "#{current_model_definition.label} was successfully created."
      else
        @layout_builder = Presenter::LayoutBuilder.new(current_presenter, current_model_definition)
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize @record
      preload_associations(@record, :form)
      @record.strict_loading! if LcpRuby.configuration.strict_loading_enabled?
      @layout_builder = Presenter::LayoutBuilder.new(current_presenter, current_model_definition)
    end

    def update
      authorize @record

      if @record.update(permitted_params)
        redirect_to resource_path(@record), notice: "#{current_model_definition.label} was successfully updated."
      else
        @layout_builder = Presenter::LayoutBuilder.new(current_presenter, current_model_definition)
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize @record
      @record.destroy!
      redirect_to resources_path, notice: "#{current_model_definition.label} was successfully deleted."
    end

    def evaluate_conditions
      authorize @record, :edit?
      @record.assign_attributes(permitted_params)
      render json: evaluate_service_conditions(@record)
    end

    def evaluate_conditions_new
      @record = @model_class.new(permitted_params)
      authorize @record, :create?
      render json: evaluate_service_conditions(@record)
    end

    private

    def set_record
      @record = @model_class.find(params[:id])
    end

    def permitted_params
      writable = current_evaluator.writable_fields.map(&:to_sym)

      # Also permit belongs_to foreign keys that appear in writable presenter form fields
      presenter_fields = (current_presenter.form_config["sections"] || [])
        .flat_map { |s| (s["fields"] || []).map { |f| f["field"] } }.compact

      fk_fields = current_model_definition.associations
        .select { |a| a.type == "belongs_to" && a.foreign_key.present? }
        .select { |a| presenter_fields.include?(a.foreign_key) || presenter_fields.include?(a.name) }
        .map { |a| a.foreign_key.to_sym }

      flat_fields = (writable + fk_fields).uniq
      nested = build_nested_permits

      if nested.any?
        params.require(:record).permit(*flat_fields, **nested)
      else
        params.require(:record).permit(*flat_fields)
      end
    end

    def build_nested_permits
      nested = {}
      current_model_definition.associations.select { |a| a.nested_attributes }.each do |assoc|
        section = find_nested_section_for(assoc.name)
        next unless section

        target_def = LcpRuby.loader.model_definition(assoc.target_model)
        next unless target_def

        child_fields = (section["fields"] || []).map { |f| f["field"].to_sym }
        child_fields += [ :id ]
        child_fields << :_destroy if assoc.nested_attributes["allow_destroy"]

        pos = sortable_position_field(section)
        child_fields << pos.to_sym unless pos.nil? || child_fields.include?(pos.to_sym)

        nested["#{assoc.name}_attributes".to_sym] = child_fields
      end
      nested
    end

    def find_nested_section_for(assoc_name)
      (current_presenter.form_config["sections"] || []).find do |s|
        s["type"] == "nested_fields" && s["association"] == assoc_name
      end
    end

    def apply_search(scope)
      search_config = current_presenter.search_config
      return scope unless search_config["enabled"]

      if params[:filter].present?
        predefined = search_config["predefined_filters"]&.find { |f| f["name"] == params[:filter] }
        scope_name = predefined&.dig("scope")
        scope = scope.send(scope_name) if scope_name && @model_class.respond_to?(scope_name)
      end

      if params[:q].present?
        searchable = (search_config["searchable_fields"] || []).select { |f| @model_class.column_names.include?(f.to_s) }
        conn = @model_class.connection
        conditions = searchable.map { |f| "#{conn.quote_column_name(f)} LIKE :q" }.join(" OR ")
        scope = scope.where(conditions, q: "%#{params[:q]}%") if conditions.present?
      end

      scope
    end

    def apply_sort(scope)
      sort_config = current_presenter.index_config["default_sort"]
      return scope unless sort_config || params[:sort]

      field = params[:sort] || sort_config&.dig("field")
      direction = params[:direction] || sort_config&.dig("direction") || "asc"
      direction = "asc" unless %w[asc desc].include?(direction.to_s.downcase)

      if field.to_s.include?(".")
        parts = field.to_s.split(".")
        assoc_name = parts[0]
        assoc = current_model_definition.associations.find { |a| a.name == assoc_name }
        return scope unless assoc

        target_def = LcpRuby.loader.model_definition(assoc.target_model)
        return scope unless target_def

        target_class = LcpRuby.registry.model_for(assoc.target_model)
        col = parts.last
        return scope unless target_class&.column_names&.include?(col)

        conn = @model_class.connection
        scope.order(Arel.sql("#{conn.quote_table_name(target_def.table_name)}.#{conn.quote_column_name(col)} #{direction}"))
      else
        return scope unless @model_class.column_names.include?(field.to_s)
        scope.order(field => direction)
      end
    end

    def summary_columns_present?
      current_presenter.table_columns.any? { |c| c["summary"].present? }
    end

    def compute_summaries(scope)
      columns = current_presenter.table_columns.select { |c| c["summary"].present? }
      columns.each_with_object({}) do |col, h|
        field = col["field"]
        next unless @model_class.column_names.include?(field)

        case col["summary"]
        when "sum"   then h[field] = scope.sum(field)
        when "avg"   then h[field] = scope.average(field)
        when "count" then h[field] = scope.where.not(field => nil).count
        end
      end
    end

    def build_nested_records(record)
      sections = current_presenter.form_config["sections"] || []
      sections.each do |section|
        next unless section["type"] == "nested_fields"

        assoc_name = section["association"]
        min = (section["min"] || 0).to_i
        next unless min > 0

        if record.respond_to?(assoc_name) && record.send(assoc_name).size < min
          existing_count = record.send(assoc_name).size
          pos = sortable_position_field(section)
          (min - existing_count).times do |i|
            new_record = record.send(assoc_name).build
            if pos && new_record.respond_to?("#{pos}=")
              new_record[pos] = existing_count + i
            end
          end
        end
      end
    end

    def sortable_position_field(section)
      return unless section["sortable"]
      section["sortable"].is_a?(String) ? section["sortable"] : "position"
    end

    def evaluate_service_conditions(record)
      results = {}
      sections = current_presenter.form_config["sections"] || []
      sections.each_with_index do |section, idx|
        %w[visible_when disable_when].each do |cond_key|
          cond = section[cond_key]
          next unless cond.is_a?(Hash) && ConditionEvaluator.condition_type(cond) == :service

          result_key = "section_#{idx}_#{cond_key == 'visible_when' ? 'visible' : 'disable'}"
          results[result_key] = ConditionEvaluator.evaluate_service(record, cond)
        end

        (section["fields"] || []).each do |field_config|
          field_name = field_config["field"]
          next unless field_name

          %w[visible_when disable_when].each do |cond_key|
            cond = field_config[cond_key]
            next unless cond.is_a?(Hash) && ConditionEvaluator.condition_type(cond) == :service

            result_key = "#{field_name}_#{cond_key == 'visible_when' ? 'visible' : 'disable'}"
            results[result_key] = ConditionEvaluator.evaluate_service(record, cond)
          end
        end
      end
      results
    end

    def resolve_loading_strategy(context)
      sort_field = params[:sort] if context == :index
      search_fields = current_presenter.search_config["searchable_fields"] if context == :index && params[:q].present?
      Presenter::IncludesResolver.resolve(
        presenter_def: current_presenter,
        model_def: current_model_definition,
        context: context,
        sort_field: sort_field,
        search_fields: search_fields
      )
    rescue => e
      Rails.logger.warn("[LcpRuby] Failed to resolve loading strategy for #{context}: #{e.message}")
      Presenter::IncludesResolver::LoadingStrategy.new
    end

    def preload_associations(record, context)
      strategy = resolve_loading_strategy(context)
      return if strategy.empty?

      assocs = strategy.includes + strategy.eager_load
      ActiveRecord::Associations::Preloader.new(records: [ record ], associations: assocs).call if assocs.any?
    rescue => e
      Rails.logger.warn("[LcpRuby] Failed to preload associations for #{context}: #{e.message}")
    end

    # Pundit uses model class to find policy
    def policy(record)
      policy_class = Authorization::PolicyFactory.policy_for(current_presenter.model)
      policy_class.new(current_user, record)
    end

    def policy_scope(scope)
      policy_class = Authorization::PolicyFactory.policy_for(current_presenter.model)
      policy_class::Scope.new(current_user, scope).resolve
    end

    def authorize(record, query = nil)
      pol = policy(record)
      query ||= "#{action_name}?"
      raise Pundit::NotAuthorizedError unless pol.public_send(query)
    end
  end
end
