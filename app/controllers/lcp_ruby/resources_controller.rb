module LcpRuby
  class ResourcesController < ApplicationController
    include LcpRuby::AssociationOptionsBuilder

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
      @field_resolver = Presenter::FieldValueResolver.new(current_model_definition, current_evaluator)
    end

    def show
      authorize @record
      preload_associations(@record, :show)
      @record.strict_loading! if LcpRuby.configuration.strict_loading_enabled?
      @layout_builder = Presenter::LayoutBuilder.new(current_presenter, current_model_definition)
      @column_set = Presenter::ColumnSet.new(current_presenter, current_evaluator)
      @action_set = Presenter::ActionSet.new(current_presenter, current_evaluator)
      @field_resolver = Presenter::FieldValueResolver.new(current_model_definition, current_evaluator)
    end

    def new
      @record = @model_class.new
      authorize @record
      apply_presenter_defaults(@record)
      build_nested_records(@record)
      @layout_builder = Presenter::LayoutBuilder.new(current_presenter, current_model_definition)
    end

    def create
      @record = @model_class.new(permitted_params)
      authorize @record

      validate_association_values!(@record)

      if @record.errors.none? && @record.save
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
      @record.assign_attributes(permitted_params)
      purge_removed_attachments!(@record)

      validate_association_values!(@record)

      if @record.errors.none? && @record.save
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

    def select_options
      authorize @model_class, :index?
      field_name = params[:field]
      field_config = find_form_field_config(field_name)
      return render(json: []) unless field_config

      # Resolve association from enriched field config (covers association_select + multi_select)
      assoc = field_config["association"] || field_config["multi_select_association"]
      # Fallback to FK lookup for non-enriched cases
      assoc ||= resolve_association_for_field(field_name)
      return render(json: []) unless assoc&.lcp_model?

      input_options = field_config["input_options"] || {}

      # Reverse cascade: resolve ancestor chain for a given value
      if params[:ancestors_for].present?
        ancestors = resolve_field_ancestors(field_name, params[:ancestors_for])
        return render json: { ancestors: ancestors }
      end

      # Tree select mode
      if params[:tree] == "true"
        tree = build_tree_select_options(assoc, input_options)
        return render json: tree
      end

      # Paginated search mode when q or page param present
      if params[:q].present? || params[:page].present?
        result = build_select_options_search(assoc, input_options)
        render json: result
      else
        options = build_select_options_json(assoc, input_options)
        render json: options
      end
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

    def inline_create_form
      target_model_name = params[:target_model]
      return head(:bad_request) unless target_model_name.present?

      target_presenter = find_presenter_for_inline_create(target_model_name)
      return head(:not_found) unless target_presenter

      target_model_def = LcpRuby.loader.model_definition(target_model_name)
      target_class = LcpRuby.registry.model_for(target_model_name)
      target_record = target_class.new

      # Authorize create on the target model
      target_policy_class = Authorization::PolicyFactory.policy_for(target_model_name)
      target_policy = target_policy_class.new(current_user, target_record)
      raise Pundit::NotAuthorizedError unless target_policy.create?

      layout_builder = Presenter::LayoutBuilder.new(target_presenter, target_model_def)
      @inline_fields = inline_form_fields(layout_builder, target_model_def)

      render partial: "lcp_ruby/resources/inline_create_form",
             locals: { fields: @inline_fields, model_name: target_model_name },
             layout: false
    end

    def inline_create
      target_model_name = params[:target_model]
      return head(:bad_request) unless target_model_name.present?

      target_model_def = LcpRuby.loader.model_definition(target_model_name)
      target_class = LcpRuby.registry.model_for(target_model_name)
      target_record = target_class.new

      # Authorize create on the target model
      target_policy_class = Authorization::PolicyFactory.policy_for(target_model_name)
      target_policy = target_policy_class.new(current_user, target_record)
      raise Pundit::NotAuthorizedError unless target_policy.create?

      permitted = inline_create_params(target_model_def)
      record = target_class.new(permitted)

      if record.save
        label_method = resolve_inline_label_method(target_model_def, params[:label_method])
        render json: { id: record.id, label: resolve_label(record, label_method) }, status: :created
      else
        render json: { errors: record.errors.full_messages }, status: :unprocessable_entity
      end
    end

    private

    def set_record
      @record = @model_class.find(params[:id])
    end

    def purge_removed_attachments!(record)
      current_model_definition.fields.select(&:attachment?).each do |field|
        remove_key = "remove_#{field.name}"
        next unless params[:record]&.dig(remove_key) == "1"

        attachment = record.send(field.name)
        attachment.purge if attachment.attached?
      end
    end

    def find_form_field_config(field_name)
      return nil unless field_name.present?

      layout_builder = Presenter::LayoutBuilder.new(current_presenter, current_model_definition)
      layout_builder.form_sections
        .flat_map { |s| s["fields"] || [] }
        .find { |f| f["field"] == field_name }
    end

    def resolve_association_for_field(field_name)
      current_model_definition.associations.find { |a| a.foreign_key == field_name.to_s }
    end

    # Walk up the depends_on chain from a field and resolve parent values.
    # Returns an array of {field, value, label} hashes from the immediate parent
    # up to the root of the dependency chain.
    def resolve_field_ancestors(field_name, value_id)
      ancestors = []
      seen = Set.new
      current_field = field_name.to_s
      current_value = value_id.to_i

      loop do
        break if seen.include?(current_field)
        seen << current_field

        # Find the field config for the current field
        field_config = find_form_field_config(current_field)
        break unless field_config

        input_options = field_config["input_options"] || {}
        depends_on = input_options["depends_on"]
        break unless depends_on

        parent_field = depends_on["field"]
        parent_fk = depends_on["foreign_key"]
        break unless parent_field && parent_fk

        # Look up the current record to get the parent FK value
        assoc = field_config["association"] || resolve_association_for_field(current_field)
        break unless assoc&.lcp_model?

        target_class = LcpRuby.registry.model_for(assoc.target_model)
        record = target_class.find_by(id: current_value)
        break unless record

        parent_value = record.respond_to?(parent_fk) ? record.send(parent_fk) : nil
        break unless parent_value.present?

        # Resolve the parent's label
        parent_field_config = find_form_field_config(parent_field)
        parent_assoc = parent_field_config && (parent_field_config["association"] || resolve_association_for_field(parent_field))
        parent_label = parent_value.to_s
        if parent_assoc&.lcp_model?
          parent_input_options = (parent_field_config["input_options"] || {}) if parent_field_config
          label_method = ((parent_input_options && parent_input_options["label_method"]) || resolve_default_label_method(parent_assoc)).to_sym
          parent_class = LcpRuby.registry.model_for(parent_assoc.target_model)
          parent_record = parent_class.find_by(id: parent_value)
          parent_label = resolve_label(parent_record, label_method) if parent_record
        end

        ancestors << { field: parent_field, value: parent_value, label: parent_label }

        # Move up the chain
        current_field = parent_field
        current_value = parent_value
      end

      ancestors
    end

    def build_select_options_json(assoc, input_options)
      depends_on_values = extract_depends_on_from_params(input_options)
      oq = build_options_query(assoc, input_options, role: current_user_role_name, depends_on_values: depends_on_values)
      format_options_for_json(oq, input_options)
    end

    def extract_depends_on_from_params(input_options)
      depends_on = input_options["depends_on"]
      return {} unless depends_on && params[:depends_on].present?

      field = depends_on["field"]
      { field => params[:depends_on][field] }
    end

    def build_select_options_search(assoc, input_options)
      target_class = LcpRuby.registry.model_for(assoc.target_model)
      depends_on_values = extract_depends_on_from_params(input_options)
      query = apply_option_scope(target_class, input_options, role: current_user_role_name)
      query = query.where(input_options["filter"]) if input_options["filter"]

      depends_on = input_options["depends_on"]
      if depends_on && depends_on_values.present?
        fk = depends_on["foreign_key"]
        parent_value = depends_on_values[depends_on["field"]]
        query = query.where(fk => parent_value) if fk && parent_value.present?
      end

      # Fulltext LIKE search on configured search_fields
      search_fields = Array(input_options["search_fields"])
      if params[:q].present? && search_fields.any?
        conn = target_class.connection
        conditions = search_fields
          .select { |f| target_class.column_names.include?(f.to_s) }
          .map { |f| "#{conn.quote_column_name(f)} LIKE :q" }
          .join(" OR ")
        sanitized_q = ActiveRecord::Base.sanitize_sql_like(params[:q])
        query = query.where(conditions, q: "%#{sanitized_q}%") if conditions.present?
      end

      query = query.order(input_options["sort"]) if input_options["sort"]

      label_method = (input_options["label_method"] || resolve_default_label_method(assoc)).to_sym
      disabled_ids = resolve_disabled_values(assoc, input_options)

      # Pagination
      page = [ (params[:page] || 1).to_i, 1 ].max
      per_page = [ [ (params[:per_page] || input_options["per_page"] || 25).to_i, 1 ].max, 100 ].min
      offset = (page - 1) * per_page

      total = query.count
      records = query.offset(offset).limit(per_page)

      options = records.map do |r|
        opt = { value: r.id, label: resolve_label(r, label_method) }
        opt[:disabled] = true if disabled_ids.include?(r.id)
        opt
      end

      {
        options: options,
        has_more: (offset + per_page) < total,
        total: total
      }
    end

    def build_tree_select_options(assoc, input_options)
      target_class = LcpRuby.registry.model_for(assoc.target_model)
      query = apply_option_scope(target_class, input_options, role: current_user_role_name)
      query = query.order(input_options["sort"]) if input_options["sort"]

      max = (input_options["max_options"] || MAX_SELECT_OPTIONS).to_i
      query = query.limit(max)

      label_method = (input_options["label_method"] || resolve_default_label_method(assoc)).to_sym
      parent_field = input_options["parent_field"] || "parent_id"
      max_depth = (input_options["max_depth"] || 10).to_i

      records = query.to_a
      build_tree_json(records, parent_field, label_method, max_depth)
    end

    def build_tree_json(records, parent_field, label_method, max_depth, parent_id = nil, depth = 0)
      return [] if depth >= max_depth

      records.select { |r| r.send(parent_field) == parent_id }.map do |r|
        {
          id: r.id,
          label: resolve_label(r, label_method),
          children: build_tree_json(records, parent_field, label_method, max_depth, r.id, depth + 1)
        }
      end
    end

    def current_user_role_name
      current_user&.send(LcpRuby.configuration.role_method).to_s
    rescue StandardError
      ""
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

      # Permit custom field names if custom_fields is enabled and custom_data is writable
      if current_model_definition.custom_fields_enabled? &&
         current_evaluator.field_writable?("custom_data")
        cf_definitions = CustomFields::Registry.for_model(current_model_definition.name)
          .select { |d| d.active && d.show_in_form }
        cf_definitions.each { |d| flat_fields << d.field_name.to_sym }
      end

      # Separate attachment fields from flat fields (they need special permitting)
      attachment_fields = current_model_definition.fields.select(&:attachment?)
      attachment_names = attachment_fields.map { |f| f.name.to_sym }
      flat_fields -= attachment_names

      nested = build_nested_permits

      # Detect multi_select fields and permit array params
      array_fields = {}
      layout_builder = Presenter::LayoutBuilder.new(current_presenter, current_model_definition)
      layout_builder.form_sections
        .flat_map { |s| s["fields"] || [] }
        .select { |f| f["input_type"] == "multi_select" }
        .each { |f| array_fields[f["field"].to_sym] = [] }

      # Add attachment fields: single as scalar, multiple as array
      attachment_fields.each do |field|
        name = field.name.to_sym
        if field.attachment_multiple?
          array_fields[name] = []
        else
          flat_fields << name
        end
      end

      permit_args = flat_fields + array_fields.map { |k, v| { k => v } }

      if nested.any?
        params.require(:record).permit(*permit_args, **nested)
      else
        params.require(:record).permit(*permit_args)
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

      # Apply default scope if configured (e.g., management presenters scoped by target_model)
      if search_config["default_scope"]
        scope_name = search_config["default_scope"]
        scope = scope.send(scope_name) if @model_class.respond_to?(scope_name)
      end

      if params[:filter].present?
        predefined = search_config["predefined_filters"]&.find { |f| f["name"] == params[:filter] }
        scope_name = predefined&.dig("scope")
        scope = scope.send(scope_name) if scope_name && @model_class.respond_to?(scope_name)
      end

      if params[:q].present?
        searchable = (search_config["searchable_fields"] || []).select { |f| @model_class.column_names.include?(f.to_s) }
        conn = @model_class.connection
        sanitized_q = ActiveRecord::Base.sanitize_sql_like(params[:q])

        conditions = searchable.map { |f| "#{conn.quote_column_name(f)} LIKE :q" }.join(" OR ")

        # Include searchable custom fields
        if current_model_definition.custom_fields_enabled?
          cf_searchable = CustomFields::Registry.for_model(current_model_definition.name)
            .select { |d| d.active && d.searchable }
          cf_conditions = cf_searchable.map do |d|
            CustomFields::Query.text_search_condition(current_model_definition.table_name, d.field_name, sanitized_q)
          end
          all_conditions = [ conditions, *cf_conditions ].reject(&:blank?)
          conditions = all_conditions.join(" OR ")
        end

        scope = scope.where(conditions, q: "%#{sanitized_q}%") if conditions.present?
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

    def validate_association_values!(record)
      layout_builder = Presenter::LayoutBuilder.new(current_presenter, current_model_definition)
      layout_builder.form_sections
        .flat_map { |s| s["fields"] || [] }
        .each do |field_config|
          field_name = field_config["field"]
          next unless field_name

          assoc = field_config["association"] || field_config["multi_select_association"]
          next unless assoc&.lcp_model?

          submitted_value = record.public_send(field_name)
          next if submitted_value.blank?

          input_options = field_config["input_options"] || {}

          # Build the allowed options using the same logic as the select builder
          options = build_select_options_json(assoc, input_options)
          allowed_ids = extract_allowed_ids(options)
          disabled_ids = resolve_disabled_values(assoc, input_options)

          submitted_ids = Array(submitted_value).map(&:to_i)

          submitted_ids.each do |sid|
            unless allowed_ids.include?(sid) && !disabled_ids.include?(sid)
              # Allow legacy scope values on existing records (edit)
              if input_options["legacy_scope"] && !record.new_record?
                legacy = resolve_legacy_record(assoc, input_options, sid)
                next if legacy
              end

              record.errors.add(field_name, I18n.t("lcp_ruby.form.errors.contains_not_allowed"))
              break
            end
          end
        end
    end

    def extract_allowed_ids(options)
      ids = Set.new
      if options.is_a?(Array) && options.first.is_a?(Hash) && options.first.key?(:group)
        # Grouped format: [{group: "...", options: [{value:, label:}]}]
        options.each { |g| g[:options].each { |o| ids << o[:value].to_i } }
      elsif options.is_a?(Array)
        # Flat format: [{value:, label:}]
        options.each { |o| ids << o[:value].to_i }
      end
      ids
    end

    def apply_presenter_defaults(record)
      layout_builder = Presenter::LayoutBuilder.new(current_presenter, current_model_definition)
      layout_builder.form_sections.each do |section|
        (section["fields"] || []).each do |field_config|
          field_name = field_config["field"]
          next unless field_name

          default_value = field_config.dig("input_options", "default_value")
          next if default_value.nil?

          if record.respond_to?("#{field_name}=") && record.public_send(field_name).blank?
            record.public_send("#{field_name}=", default_value)
          end
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

        if record.respond_to?(assoc_name) && record.public_send(assoc_name).size < min
          existing_count = record.public_send(assoc_name).size
          pos = sortable_position_field(section)
          (min - existing_count).times do |i|
            new_record = record.public_send(assoc_name).build
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

    # -- Inline create helpers --

    def find_presenter_for_inline_create(model_name)
      LcpRuby.loader.presenter_definitions.values.find do |p|
        p.model == model_name && p.form_config["sections"]&.any?
      end
    end

    def inline_create_params(model_def)
      all_fields = model_def.fields.map { |f| f.name.to_sym }

      # Filter through permission evaluator to respect field-level write restrictions
      begin
        perm_def = LcpRuby.loader.permission_definition(model_def.name)
        evaluator = Authorization::PermissionEvaluator.new(perm_def, current_user, model_def.name)
        writable = evaluator.writable_fields.map(&:to_sym)
        allowed = all_fields & writable
      rescue LcpRuby::MetadataError
        # No permission definition found; allow all model fields
        allowed = all_fields
      end

      params.require(:inline_record).permit(*allowed)
    end

    def resolve_inline_label_method(model_def, explicit_method)
      return explicit_method.to_sym if explicit_method.present?
      method = model_def.label_method
      method && method != "to_s" ? method.to_sym : :to_label
    end

    def inline_form_fields(layout_builder, model_def)
      simple_types = %w[string text integer float decimal boolean date datetime enum email phone url color]
      layout_builder.form_sections
        .flat_map { |s| s["fields"] || [] }
        .select do |f|
          field_def = model_def.fields.find { |fd| fd.name == f["field"] }
          next false unless field_def
          # Only include simple field types (no associations, no nested)
          simple_types.include?(field_def.type.to_s) || field_def.enum?
        end
        .map do |f|
          field_def = model_def.fields.find { |fd| fd.name == f["field"] }
          {
            name: f["field"],
            label: f["label"] || f["field"].humanize,
            type: field_def.type.to_s,
            required: field_def.validations&.any? { |v| v.type == "presence" },
            enum_values: field_def.enum? ? field_def.enum_value_names : nil,
            placeholder: f["placeholder"]
          }
        end
    end
  end
end
