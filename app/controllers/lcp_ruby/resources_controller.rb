require "digest"

module LcpRuby
  class ResourcesController < ApplicationController
    include LcpRuby::AssociationOptionsBuilder
    include LcpRuby::DialogRendering

    before_action :set_record, only: [ :show, :edit, :update, :destroy, :evaluate_conditions, :reorder, :reparent ]
    before_action :set_record_with_discarded, only: [ :restore, :permanently_destroy ]

    def index
      authorize @model_class

      if api_model?
        load_api_index
        return
      end

      scope = policy_scope(@model_class)
      scope = apply_soft_delete_scope(scope)

      # Apply default saved filter when no explicit filter params are present
      if no_explicit_filter_params? && SavedFilters::Registry.available? && current_presenter.saved_filters_enabled?
        default = SavedFilters::Resolver.default_filter_for(
          presenter_name: current_presenter.name,
          user: current_user,
          evaluator: current_evaluator
        )
        if default
          params[:saved_filter] = default.id.to_s
        end
      end

      case current_presenter.index_layout
      when :tree
        load_tree_index(scope) if current_model_definition.tree?
      when :tiles
        load_flat_index(scope)
      else
        load_flat_index(scope)
      end
    end

    def show
      authorize @record

      if api_model?
        @layout_builder = Presenter::LayoutBuilder.new(current_presenter, current_model_definition)
        @column_set = Presenter::ColumnSet.new(current_presenter, current_evaluator)
        @action_set = Presenter::ActionSet.new(current_presenter, current_evaluator, context: condition_context)
        @field_resolver = Presenter::FieldValueResolver.new(current_model_definition, current_evaluator)
        return
      end

      @layout_builder = Presenter::LayoutBuilder.new(current_presenter, current_model_definition)
      load_show_virtual_columns
      preload_associations(@record, :show)
      @record.strict_loading! if LcpRuby.configuration.strict_loading_enabled?
      @column_set = Presenter::ColumnSet.new(current_presenter, current_evaluator)
      @action_set = Presenter::ActionSet.new(current_presenter, current_evaluator, context: condition_context)
      @field_resolver = Presenter::FieldValueResolver.new(current_model_definition, current_evaluator)
    end

    def new
      return head(:not_found) if api_model?
      @record = @model_class.new
      authorize @record
      apply_presenter_defaults(@record)

      if dialog_context?
        return render_dialog_form
      end

      build_nested_records(@record)
      @layout_builder = Presenter::LayoutBuilder.new(current_presenter, current_model_definition)
    end

    def create
      return head(:not_found) if api_model?
      @record = @model_class.new(permitted_params)
      authorize @record

      process_json_field_params(@record)
      validate_association_values!(@record)

      if @record.errors.none? && @record.save
        if dialog_context?
          return render_dialog_success(params[:on_success])
        end

        redirect_to redirect_path_for("create", @record),
          notice: I18n.t("lcp_ruby.flash.created", model: current_model_definition.label,
            default: "%{model} was successfully created.")
      else
        if dialog_context?
          return render_dialog_form_with_errors
        end

        @layout_builder = Presenter::LayoutBuilder.new(current_presenter, current_model_definition)
        render :new, status: :unprocessable_content
      end
    end

    def edit
      return head(:not_found) if api_model?
      authorize @record

      if dialog_context?
        return render_dialog_form
      end

      @layout_builder = Presenter::LayoutBuilder.new(current_presenter, current_model_definition)
      load_edit_virtual_columns
      preload_associations(@record, :form)
      @record.strict_loading! if LcpRuby.configuration.strict_loading_enabled?
    end

    def update
      return head(:not_found) if api_model?
      authorize @record
      @record.assign_attributes(permitted_params)
      purge_removed_attachments!(@record)

      process_json_field_params(@record)
      validate_association_values!(@record)

      if @record.errors.none? && @record.save
        if dialog_context?
          return render_dialog_success(params[:on_success])
        end

        redirect_to redirect_path_for("update", @record),
          notice: I18n.t("lcp_ruby.flash.updated", model: current_model_definition.label,
            default: "%{model} was successfully updated.")
      else
        if dialog_context?
          return render_dialog_form_with_errors
        end

        @layout_builder = Presenter::LayoutBuilder.new(current_presenter, current_model_definition)
        load_dirty_record_virtual_columns
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      return head(:not_found) if api_model?
      authorize @record
      if current_model_definition.soft_delete?
        @record.discard!(by: current_user)
        redirect_to resources_path,
          notice: I18n.t("lcp_ruby.flash.archived", model: current_model_definition.label,
                         default: "%{model} was successfully archived.")
      else
        @record.destroy!
        redirect_to resources_path,
          notice: I18n.t("lcp_ruby.flash.deleted", model: current_model_definition.label,
                         default: "%{model} was successfully deleted.")
      end
    end

    def restore
      authorize @record
      @record.undiscard!
      redirect_to resources_path,
        notice: I18n.t("lcp_ruby.flash.restored", model: current_model_definition.label,
                       default: "%{model} was successfully restored.")
    end

    def permanently_destroy
      authorize @record
      @record.destroy!
      redirect_to resources_path,
        notice: I18n.t("lcp_ruby.flash.permanently_deleted", model: current_model_definition.label,
          default: "%{model} was permanently deleted.")
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

      # API-backed target model: delegate to data source
      if api_target_model?(assoc)
        return render json: build_api_select_options(assoc, input_options)
      end

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

    def parse_ql
      authorize @model_class, :index?

      ql_text = params[:ql].to_s.first(Search::QueryLanguageParser::MAX_INPUT_LENGTH + 1)
      max_depth = current_presenter.advanced_filter_config["max_nesting_depth"] || 2
      parser = Search::QueryLanguageParser.new(ql_text, max_nesting_depth: max_depth)
      tree = parser.parse

      render json: { success: true, tree: tree }
    rescue Search::QueryLanguageParser::ParseError => e
      render json: { success: false, error: e.message, position: e.position }
    end

    def filter_fields
      authorize @model_class, :index?

      builder = Search::FilterMetadataBuilder.new(current_presenter, current_model_definition, current_evaluator)
      metadata = builder.build

      result = { fields: metadata[:fields] }
      result[:scopes] = metadata[:scopes] if metadata[:scopes]&.any?
      render json: result
    end

    def reorder
      unless current_model_definition.positioned?
        head :not_found
        return
      end

      authorize @record, :update?
      authorize_position_field!

      stale = verify_list_version!
      return if stale

      position_value = parse_position_param
      pos_field = current_model_definition.positioning_field
      @record.update!(pos_field => position_value)

      render json: {
        position: @record.reload.send(pos_field),
        list_version: compute_list_version(@record)
      }
    end

    def reparent
      unless current_model_definition.tree?
        head :not_found
        return
      end

      authorize @record, :update?
      authorize_parent_field_writable!

      stale = verify_tree_version!
      return if stale

      parent_field = current_model_definition.tree_parent_field
      new_parent_id = parse_parent_id_param

      @record.send("#{parent_field}=", new_parent_id)

      # Optional position when tree is ordered
      if params[:position].present? && current_model_definition.tree_ordered?
        pos_field = current_model_definition.tree_position_field
        @record.send("#{pos_field}=", parse_position_param)
      end

      if @record.save
        render json: {
          id: @record.id,
          parent_id: @record[parent_field],
          tree_version: compute_tree_version
        }
      else
        render json: { errors: @record.errors.full_messages }, status: :unprocessable_content
      end
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
        render json: { errors: record.errors.full_messages }, status: :unprocessable_content
      end
    end

    private

    def load_api_index
      # Translate filter params for API data source
      field_names = current_model_definition.fields.map(&:name)
      raw_filters = params[:f]&.to_unsafe_h || {}
      supported_ops = @model_class.lcp_data_source&.supported_operators

      filters = DataSource::ApiFilterTranslator.translate(
        raw_filters,
        field_names: field_names,
        supported_operators: supported_ops
      )

      # Sort
      sort = if current_sort_field.present?
        { field: current_sort_field, direction: current_sort_direction }
      end

      page = (params[:page] || 1).to_i
      per = effective_per_page

      @api_result = @model_class.lcp_search(filters: filters, sort: sort, page: page, per: per)

      # Wrap in Kaminari-compatible array for view pagination
      @records = Kaminari.paginate_array(
        @api_result.to_a,
        total_count: @api_result.total_count
      ).page(page).per(per)

      setup_index_view_objects
    end

    def load_flat_index(scope)
      scope = apply_advanced_search(scope)
      scope = apply_sort(scope)
      scope = apply_virtual_columns(scope)

      # Load saved filters for the UI
      if SavedFilters::Registry.available? && current_presenter.saved_filters_enabled?
        @saved_filters = SavedFilters::Resolver.visible_filters(
          presenter_name: current_presenter.name,
          user: current_user,
          evaluator: current_evaluator
        )
        @slot_locals = (@slot_locals || {}).merge(
          saved_filters: @saved_filters,
          active_saved_filter: @active_saved_filter,
          saved_filter_warnings: @saved_filter_warnings
        )
      end

      @summaries = compute_summaries(scope) if summary_columns_present?
      compute_summary_bar(scope) if current_presenter.summary_enabled?

      strategy = resolve_loading_strategy(:index)
      scope = strategy.apply(scope)
      scope = scope.strict_loading if LcpRuby.configuration.strict_loading_enabled?

      @records = scope.page(params[:page]).per(effective_per_page)

      # Batch-preload API associations after AR scope materializes
      strategy.apply_api_preloads(@records.to_a) if strategy.api_preloads.any?

      # GROUP BY scopes break Kaminari's .count (returns Hash instead of Integer).
      # Pre-compute total via a clean scope and inject it.
      if @has_grouped_virtual_columns
        total = scope.except(:select, :group, :joins).distinct.count(:id)
        @records.define_singleton_method(:total_count) { total }
      end

      setup_index_view_objects
    end

    def load_tree_index(scope)
      parent_field = current_model_definition.tree_parent_field
      scope = scope.all unless scope.is_a?(ActiveRecord::Relation)
      scope = apply_virtual_columns(scope)

      # Detect if search is active
      @search_active = search_active?

      if @search_active
        # Run search pipeline to get matching IDs
        filtered_scope = apply_advanced_search(scope)
        filtered_scope = apply_sort(filtered_scope)
        @match_ids = Set.new(filtered_scope.pluck(:id))

        # Load all records to build complete tree with ancestor context
        all_records = scope.to_a
        @children_map, @roots = build_filtered_tree(all_records, @match_ids, parent_field)
      else
        # Load all records (no pagination for tree view)
        sorted = apply_sort(scope)
        sorted = sorted.all unless sorted.is_a?(ActiveRecord::Relation)
        all_records = sorted.to_a
        @children_map = all_records.group_by { |r| r[parent_field] }
        @roots = @children_map[nil] || []
        @match_ids = nil
      end

      @tree_version = compute_tree_version if current_presenter.reparentable?

      # Precompute subtree IDs from in-memory children_map (avoids N+1 CTE queries per row)
      if current_presenter.reparentable?
        @subtree_ids_map = precompute_subtree_ids(@children_map)
      end

      setup_index_view_objects
    end

    def setup_index_view_objects
      @column_set = Presenter::ColumnSet.new(current_presenter, current_evaluator)
      @fk_map = @column_set.fk_association_map(current_model_definition)
      @action_set = Presenter::ActionSet.new(current_presenter, current_evaluator, context: condition_context)
      @field_resolver = Presenter::FieldValueResolver.new(current_model_definition, current_evaluator)
    end

    # Inject virtual column subqueries/expressions into the scope for index/tree views.
    def apply_virtual_columns(scope)
      vc_names = collect_virtual_column_names(:index)
      return scope if vc_names.empty?

      scope, _service_only, @has_grouped_virtual_columns = VirtualColumns::Builder.apply(
        scope, current_model_definition, vc_names.to_a, current_user: current_user
      )

      scope
    end

    # Collect virtual column names needed for a given context.
    def collect_virtual_column_names(context)
      VirtualColumns::Collector.collect(
        presenter_def: current_presenter,
        model_def: current_model_definition,
        context: context,
        sort_field: context == :index ? params[:sort] : nil
      )
    end

    def effective_per_page
      options = current_presenter.per_page_options
      if options.is_a?(Array) && params[:per_page].present?
        requested = params[:per_page].to_i
        return requested if options.include?(requested)
      end
      current_presenter.per_page
    end

    def compute_summary_bar(scope)
      fields = current_presenter.summary_config["fields"]
      return unless fields.is_a?(Array) && fields.any?

      col_names = @model_class.column_names
      summary_bar = fields.filter_map do |field_config|
        field_name = field_config["field"]
        function = field_config["function"]
        next unless field_name && function
        next unless col_names.include?(field_name)

        # Strip aggregate subquery columns that would produce invalid SQL
        # inside COUNT/SUM/etc.
        plain = scope.unscope(:select)
        value = case function
        when "sum"   then plain.sum(field_name)
        when "avg"   then plain.average(field_name)
        when "count" then plain.count
        when "min"   then plain.minimum(field_name)
        when "max"   then plain.maximum(field_name)
        end

        { value: value, function: function, config: field_config }
      end

      @slot_locals = (@slot_locals || {}).merge(summary_bar: summary_bar)
    end

    # Load virtual column values for a show page record.
    def load_show_virtual_columns
      load_record_virtual_columns(:show)
    end

    # Load virtual column values for an edit page record.
    def load_edit_virtual_columns
      load_record_virtual_columns(:edit)
    end

    # Load virtual columns onto a dirty record (update validation failure).
    # Loads a clean record with VC expressions and copies values as singleton methods.
    def load_dirty_record_virtual_columns
      load_record_virtual_columns(:edit, dirty: true)
    end

    # Shared loader: re-queries @record with VC subqueries and resolves service VCs.
    # When dirty: true, copies values as singleton methods instead of replacing @record.
    def load_record_virtual_columns(context, dirty: false)
      vc_names = collect_virtual_column_names(context)
      return if vc_names.empty?

      scope = @model_class.where(id: @record.id)
      scope, service_only, _grouped = VirtualColumns::Builder.apply(
        scope, current_model_definition, vc_names.to_a, current_user: current_user
      )

      clean_record = scope.first

      if dirty
        (vc_names - service_only.to_set).each do |name|
          value = clean_record&.public_send(name)
          @record.define_singleton_method(name) { value }
        end
      elsif clean_record
        @record = clean_record
      end

      resolve_service_virtual_columns(@record, service_only)
    end

    # Compute service virtual column values and define singleton methods on the record.
    def resolve_service_virtual_columns(record, service_names)
      return if service_names.blank?

      service_names.each do |vc_name|
        vc_def = current_model_definition.virtual_column(vc_name)
        next unless vc_def

        service = Services::Registry.lookup_vc_service(vc_def.service)
        next unless service

        value = service.call(record, options: vc_def.options)
        record.define_singleton_method(vc_name) { value }
      end
    end

    def search_active?
      params[:qs].present? || params[:f].present? || params[:filter].present? || params[:cf].present?
    end

    def build_filtered_tree(all_records, match_ids, parent_field)
      # Build lookup
      by_id = all_records.index_by(&:id)

      # Collect ancestor IDs for all matching records
      ancestor_ids = Set.new
      match_ids.each do |mid|
        record = by_id[mid]
        next unless record

        pid = record[parent_field]
        while pid.present? && !ancestor_ids.include?(pid)
          ancestor_ids << pid
          parent_record = by_id[pid]
          break unless parent_record
          pid = parent_record[parent_field]
        end
      end

      display_ids = match_ids | ancestor_ids
      display_records = all_records.select { |r| display_ids.include?(r.id) }

      children_map = display_records.group_by { |r| r[parent_field] }
      roots = children_map[nil] || []

      [ children_map, roots ]
    end

    # Build a Hash { record_id => "id1,id2,..." } of subtree IDs from the in-memory children_map.
    # This replaces per-row `record.subtree_ids` calls that each fire a recursive CTE query.
    def precompute_subtree_ids(children_map)
      result = {}
      collect_subtree = ->(record_id) do
        ids = [ record_id ]
        (children_map[record_id] || []).each { |child| ids.concat(collect_subtree.call(child.id)) }
        ids
      end
      children_map.each_value do |records|
        records.each do |record|
          result[record.id] = collect_subtree.call(record.id).join(",") unless result.key?(record.id)
        end
      end
      result
    end

    def compute_tree_version
      parent_field = current_model_definition.tree_parent_field
      pairs = @model_class.order(:id).pluck(:id, parent_field)
      Digest::SHA256.hexdigest(pairs.map { |id, pid| "#{id}:#{pid}" }.join(","))
    end

    def no_explicit_filter_params?
      params[:f].blank? && params[:filter].blank? && params[:qs].blank? &&
        params[:saved_filter].blank? && params[:scope].blank?
    end

    def set_record
      if api_model?
        @record = @model_class.find(params[:id])
      else
        scope = apply_soft_delete_scope(@model_class)
        @record = scope.find(params[:id])
      end
    end

    def set_record_with_discarded
      @record = @model_class.find(params[:id])
    end

    VALID_REDIRECT_TARGETS = %w[index show edit new].freeze

    def redirect_path_for(action, record)
      target = current_presenter.options&.dig("redirect_after", action)

      if target && !VALID_REDIRECT_TARGETS.include?(target)
        Rails.logger.warn("[LcpRuby] Invalid redirect_after target '#{target}' for action '#{action}' " \
                          "in presenter '#{current_presenter.name}', falling back to 'show'")
        target = nil
      end

      case target
      when "index" then resources_path
      when "show" then resource_path(record)
      when "edit" then edit_resource_path(record)
      when "new" then new_resource_path
      else resource_path(record)
      end
    end

    def apply_soft_delete_scope(scope)
      return scope unless current_model_definition.soft_delete?

      case current_presenter.scope
      when "discarded"
        scope.discarded
      when "with_discarded"
        scope.with_discarded
      else
        scope.kept
      end
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

    # Check if the association's target model is API-backed.
    def api_target_model?(assoc)
      target_class = LcpRuby.registry.model_for(assoc.target_model)
      target_class.respond_to?(:lcp_api_model?) && target_class.lcp_api_model?
    rescue LcpRuby::RegistryError
      false
    end

    # Build select options for an API-backed target model via its data source.
    def build_api_select_options(assoc, input_options)
      target_class = LcpRuby.registry.model_for(assoc.target_model)
      label_method = input_options["label_method"] || resolve_default_label_method(assoc)
      limit = (input_options["max_options"] || MAX_SELECT_OPTIONS).to_i

      options = target_class.lcp_select_options(
        search: params[:q],
        sort: input_options["sort"],
        label_method: label_method,
        limit: limit
      )

      if params[:q].present? || params[:page].present?
        { options: options, has_more: false, total: options.size }
      else
        options
      end
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

      # Permit custom field names if custom_fields is enabled (per-field permission check)
      if current_model_definition.custom_fields_enabled?
        cf_definitions = CustomFields::Registry.for_model(current_model_definition.name)
          .select { |d| d.active && d.show_in_form }
        cf_definitions.each do |d|
          flat_fields << d.field_name.to_sym if current_evaluator.field_writable?(d.field_name)
        end
      end

      # Exclude json_field columns from flat permits (handled by process_json_field_params)
      json_field_names = (current_presenter.form_config["sections"] || [])
        .select { |s| s["type"] == "nested_fields" && s["json_field"] }
        .map { |s| s["json_field"].to_sym }
      flat_fields -= json_field_names

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

    def build_nested_records(record)
      sections = current_presenter.form_config["sections"] || []
      sections.each do |section|
        next unless section["type"] == "nested_fields"

        if section["json_field"]
          # Pre-populate empty JSON items for min requirement
          json_field_name = section["json_field"]
          min = (section["min"] || 0).to_i
          next unless min > 0

          current_items = record.respond_to?(json_field_name) ? (record.send(json_field_name) || []) : []
          if current_items.size < min
            empty_items = (min - current_items.size).times.map { {} }
            record.send("#{json_field_name}=", current_items + empty_items)
          end
          next
        end

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

    # Process json_field sections: parse hash-of-hashes params into array of hashes.
    # For model-backed sections (target_model), wraps items in JsonItemWrapper
    # for type coercion and validation.
    def process_json_field_params(record)
      layout_builder = Presenter::LayoutBuilder.new(current_presenter, current_model_definition)
      sections = layout_builder.form_sections

      sections.each do |section|
        next unless section["type"] == "nested_fields" && section["json_field"]

        json_field_name = section["json_field"]
        raw = params.dig(:record, json_field_name)
        next unless raw.is_a?(ActionController::Parameters) || raw.is_a?(Hash)

        # Collect allowed field names from the section (including sub_sections)
        allowed_keys = (section["fields"] || []).map { |f| f["field"] }.compact
        (section["sub_sections"] || []).each do |ss|
          allowed_keys += (ss["fields"] || []).map { |f| f["field"] }.compact
        end
        allowed_keys.uniq!
        target_model_def = section["target_model_definition"]

        items = []
        raw.each_value.with_index do |item_params, idx|
          item_params = ActionController::Parameters.new(item_params) unless item_params.is_a?(ActionController::Parameters)
          item_params = item_params.permit(*allowed_keys, :_destroy)
          next if item_params[:_destroy].to_s.in?(%w[1 true])

          item = {}
          allowed_keys.each do |key|
            item[key] = item_params[key] if item_params.key?(key)
          end
          # Skip rows where every permitted value is blank (empty template rows).
          # Note: boolean "0" is not blank in Ruby, so unchecked checkboxes survive.
          next if item.values.all?(&:blank?)

          if target_model_def
            # Wrap in JsonItemWrapper for type coercion and validation
            wrapper = JsonItemWrapper.new(item, target_model_def)
            wrapper.validate_with_model_rules!

            if wrapper.errors.any?
              wrapper.errors.each do |error|
                record.errors.add(
                  :base,
                  "#{json_field_name} item #{idx + 1}: #{error.attribute} #{error.message}"
                )
              end
            end

            items << wrapper.to_hash
          else
            items << item
          end
        end

        # Enforce min/max item limits
        min = section["min"]&.to_i
        if min && min > 0 && items.size < min
          record.errors.add(:base, "#{json_field_name}: too few items (minimum is #{min})")
        end

        max = section["max"]&.to_i
        if max && max > 0 && items.size > max
          record.errors.add(:base, "#{json_field_name}: too many items (maximum is #{max})")
          items = items.first(max)
        end

        record.send("#{json_field_name}=", items)
      end
    end

    def sortable_position_field(section)
      return unless section["sortable"]
      section["sortable"].is_a?(String) ? section["sortable"] : "position"
    end

    def evaluate_service_conditions(record)
      ctx = condition_context
      results = {}
      sections = current_presenter.form_config["sections"] || []
      sections.each_with_index do |section, idx|
        %w[visible_when disable_when].each do |cond_key|
          cond = section[cond_key]
          next unless cond.is_a?(Hash) && !ConditionEvaluator.client_evaluable?(cond)

          result_key = "section_#{idx}_#{cond_key == 'visible_when' ? 'visible' : 'disable'}"
          results[result_key] = ConditionEvaluator.evaluate_any(record, cond, context: ctx)
        end

        (section["fields"] || []).each do |field_config|
          field_name = field_config["field"]
          next unless field_name

          %w[visible_when disable_when].each do |cond_key|
            cond = field_config[cond_key]
            next unless cond.is_a?(Hash) && !ConditionEvaluator.client_evaluable?(cond)

            result_key = "#{field_name}_#{cond_key == 'visible_when' ? 'visible' : 'disable'}"
            results[result_key] = ConditionEvaluator.evaluate_any(record, cond, context: ctx)
          end
        end
      end
      results
    end

    def resolve_loading_strategy(context)
      sort_field = params[:sort] if context == :index
      search_fields = current_presenter.search_config["searchable_fields"] if context == :index && params[:qs].present?
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

    def policy_scope(scope)
      policy_class = Authorization::PolicyFactory.policy_for(current_presenter.model)
      policy_class::Scope.new(current_user, scope).resolve
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

    def authorize_parent_field_writable!
      authorize_field_writable!(current_model_definition.tree_parent_field, "tree parent")
    end

    def parse_parent_id_param
      raw = params[:parent_id]
      return nil if raw.blank? || raw == "null"
      raw.to_i
    end

    def verify_tree_version!
      return false unless params[:tree_version].present?

      current_version = compute_tree_version
      return false if current_version == params[:tree_version]

      render json: { error: "tree_version_mismatch", tree_version: current_version },
             status: :conflict
      true
    end

    def authorize_position_field!
      authorize_field_writable!(current_model_definition.positioning_field, "positioning")
    end

    def authorize_field_writable!(field, label = field)
      unless current_evaluator.field_writable?(field)
        raise Pundit::NotAuthorizedError,
          "Not allowed to write #{label} field '#{field}'"
      end
    end

    def verify_list_version!
      return false unless params[:list_version].present?

      current_version = compute_list_version(@record)
      return false if current_version == params[:list_version]

      render json: { error: "list_version_mismatch", list_version: current_version },
             status: :conflict
      true
    end

    def compute_list_version(record)
      scope = @model_class.all
      current_model_definition.positioning_scope.each do |col|
        scope = scope.where(col => record.send(col))
      end
      pos_field = current_model_definition.positioning_field
      ids_in_order = scope.order(pos_field => :asc).pluck(:id)
      Digest::SHA256.hexdigest(ids_in_order.join(","))
    end

    VALID_POSITION_KEYS = %i[after before].freeze

    def parse_position_param
      raw = params[:position]
      case raw
      when ActionController::Parameters, Hash
        h = raw.to_unsafe_h.transform_values { |v| v.to_i }.symbolize_keys
        invalid = h.keys - VALID_POSITION_KEYS
        if invalid.any?
          raise ActionController::BadRequest, "Invalid position keys: #{invalid.join(', ')}. Expected: after, before"
        end
        h
      when "first"
        :first
      when "last"
        :last
      else
        raw.to_i
      end
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
