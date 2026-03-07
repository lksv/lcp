module LcpRuby
  class ApplicationController < LcpRuby.configuration.parent_controller.constantize
    include Pundit::Authorization

    helper LcpRuby::DisplayHelper
    helper LcpRuby::DisplayTemplateHelper
    helper LcpRuby::FormHelper
    helper LcpRuby::LayoutHelper
    helper LcpRuby::ConditionHelper
    helper LcpRuby::TreeHelper
    helper LcpRuby::ViewSlotHelper

    layout "lcp_ruby/application"

    before_action :authenticate_user!
    before_action :set_presenter_and_model
    before_action :authorize_presenter_access

    helper_method :current_presenter, :current_model_definition, :current_evaluator,
                  :resource_path, :resources_path, :new_resource_path, :edit_resource_path,
                  :reorder_resource_path, :reparent_resource_path,
                  :restore_resource_path, :permanently_destroy_resource_path,
                  :single_action_path, :select_options_path, :saved_filters_path,
                  :toggle_direction, :current_sort_field, :current_sort_direction,
                  :current_view_group, :sibling_views,
                  :impersonating?, :impersonated_role, :available_roles_for_impersonation,
                  :breadcrumbs, :compute_list_version_from_records,
                  :filter_metadata, :condition_context, :api_model?

    rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
    rescue_from LcpRuby::MetadataError, with: :metadata_error
    rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
    rescue_from LcpRuby::DataSource::RecordNotFound, with: :record_not_found

    private

    def authenticate_user!
      # Public view groups allow unauthenticated access
      if current_request_public?
        LcpRuby::Current.user = current_user || anonymous_user
        return
      end

      LcpRuby::Current.request_id = request.request_id

      case LcpRuby.configuration.authentication
      when :none
        # No auth needed — current_user returns default OpenStruct
        LcpRuby::Current.user = current_user
      when :built_in
        unless current_user
          session[:"user_return_to"] = request.fullpath
          redirect_to lcp_ruby.new_user_session_path
          return
        end
        unless current_user.respond_to?(:active?) && current_user.active?
          sign_out current_user if respond_to?(:sign_out, true)
          redirect_to lcp_ruby.new_user_session_path,
                      alert: I18n.t("lcp_ruby.auth.account_deactivated")
          return
        end
        LcpRuby::Current.user = current_user
      when :external
        raise "Host app must implement authentication" unless current_user
        LcpRuby::Current.user = current_user
      end
    end

    def current_user
      case LcpRuby.configuration.authentication
      when :none
        # Use a distinct ivar to avoid collision with Devise's @current_user
        @_lcp_none_user ||= OpenStruct.new(
          id: 0,
          LcpRuby.configuration.role_method => [ "admin" ],
          name: "Development User"
        )
      when :built_in
        # Use Warden directly to bypass host app's current_user override
        @current_user ||= warden.authenticate(scope: :user)
      else
        super
      end
    end

    def warden
      request.env["warden"]
    end

    def current_request_public?
      slug = params[:lcp_slug]
      return false unless slug

      presenter = Presenter::Resolver.find_by_slug(slug)
      return false unless presenter

      view_group = LcpRuby.loader.view_group_for_presenter(presenter.name)
      view_group&.public?
    rescue LcpRuby::MetadataError
      false
    end

    def anonymous_user
      OpenStruct.new(
        id: nil,
        LcpRuby.configuration.role_method => [],
        name: "Anonymous"
      )
    end

    def set_presenter_and_model
      slug = params[:lcp_slug]
      return unless slug

      @presenter_definition = Presenter::Resolver.find_by_slug(slug)
      @model_definition = LcpRuby.loader.model_definition(@presenter_definition.model)
      @model_class = LcpRuby.registry.model_for(@presenter_definition.model)
    end

    def authorize_presenter_access
      return unless @presenter_definition

      unless current_evaluator.can_access_presenter?(@presenter_definition.name)
        log_authorization_denied(
          action: "access_presenter",
          resource: @presenter_definition.name,
          detail: "presenter access denied"
        )
        raise Pundit::NotAuthorizedError, "not allowed to access presenter #{@presenter_definition.name}"
      end
    end

    def current_presenter
      @presenter_definition
    end

    def current_model_definition
      @model_definition
    end

    def condition_context
      @condition_context ||= { current_user: current_user }
    end

    def api_model?
      current_model_definition&.api_model? == true
    end

    def current_evaluator
      @current_evaluator ||= begin
        perm_def = LcpRuby.loader.permission_definition(@presenter_definition.model)
        user = impersonating? ? impersonated_user : current_user
        Authorization::PermissionEvaluator.new(perm_def, user, @presenter_definition.model)
      end
    end

    def filter_metadata
      @filter_metadata ||= Search::FilterMetadataBuilder.new(
        @presenter_definition, @model_definition, current_evaluator
      ).build
    end

    # -- Impersonation helpers --

    def impersonating?
      session[:lcp_impersonate_role].present? && can_impersonate_current_user?
    end

    def impersonated_role
      session[:lcp_impersonate_role] if impersonating?
    end

    def available_roles_for_impersonation
      return [] unless can_impersonate_current_user?

      roles = LcpRuby.loader.permission_definitions.values
        .flat_map { |pd| pd.roles.keys }

      # Include roles from DB-backed permission definitions
      if Permissions::Registry.available?
        roles.concat(
          Permissions::Registry.all_definitions
            .flat_map { |pd| pd.roles.keys }
        )
      end

      roles.uniq.sort
    end

    def can_impersonate_current_user?
      allowed = LcpRuby.configuration.impersonation_roles
      return false if allowed.empty?

      user_roles = Array(current_user&.send(LcpRuby.configuration.role_method)).map(&:to_s)
      (user_roles & allowed.map(&:to_s)).any?
    end

    def impersonated_user
      role = session[:lcp_impersonate_role]
      # Build a proxy user object that returns the impersonated role
      ImpersonatedUser.new(current_user, role)
    end

    # -- Path helpers --

    def resource_path(record)
      lcp_ruby.resource_path(lcp_slug: current_presenter.slug, id: record.respond_to?(:id) ? record.id : record)
    end

    def resources_path
      lcp_ruby.resources_path(lcp_slug: current_presenter.slug)
    end

    def new_resource_path
      lcp_ruby.new_resource_path(lcp_slug: current_presenter.slug)
    end

    def edit_resource_path(record)
      lcp_ruby.edit_resource_path(lcp_slug: current_presenter.slug, id: record.respond_to?(:id) ? record.id : record)
    end

    def single_action_path(record, action_name:)
      lcp_ruby.single_action_path(lcp_slug: current_presenter.slug, id: record.respond_to?(:id) ? record.id : record, action_name: action_name)
    end

    def reorder_resource_path(record)
      lcp_ruby.reorder_resource_path(lcp_slug: current_presenter.slug, id: record.respond_to?(:id) ? record.id : record)
    end

    def reparent_resource_path(record)
      lcp_ruby.reparent_resource_path(lcp_slug: current_presenter.slug, id: record.respond_to?(:id) ? record.id : record)
    end

    def restore_resource_path(record)
      lcp_ruby.restore_resource_path(lcp_slug: current_presenter.slug, id: record.respond_to?(:id) ? record.id : record)
    end

    def permanently_destroy_resource_path(record)
      lcp_ruby.permanently_destroy_resource_path(lcp_slug: current_presenter.slug, id: record.respond_to?(:id) ? record.id : record)
    end

    def select_options_path
      lcp_ruby.select_options_path(lcp_slug: current_presenter.slug)
    end

    def saved_filters_path
      lcp_ruby.saved_filters_path(lcp_slug: current_presenter.slug)
    end

    # -- View group helpers --

    def current_view_group
      return unless current_presenter

      @current_view_group ||= LcpRuby.loader.view_group_for_presenter(current_presenter.name)
    end

    def sibling_views
      return [] unless current_view_group

      current_view_group.views.map do |view|
        presenter = LcpRuby.loader.presenter_definitions[view["presenter"]]
        next unless presenter

        view.merge("slug" => presenter.slug, "presenter_name" => presenter.name)
      end.compact
    end

    # -- Breadcrumbs --

    def breadcrumbs
      return @breadcrumbs if defined?(@breadcrumbs)

      @breadcrumbs = Presenter::BreadcrumbBuilder.new(
        view_group: current_view_group,
        record: @record,
        action: action_name,
        path_helper: Presenter::BreadcrumbPathHelper.new(lcp_ruby)
      ).build
    rescue => e
      raise unless Rails.env.production?
      Rails.logger.error(
        "[LcpRuby::Breadcrumbs] Failed to build breadcrumbs: #{e.class}: #{e.message} " \
        "(controller=#{self.class.name}, slug=#{params[:lcp_slug]}, action=#{action_name}, record_id=#{@record&.id})"
      )
      @breadcrumbs = []
    end

    # -- View helpers --

    def toggle_direction(field)
      if current_sort_field == field && current_sort_direction == "asc"
        "desc"
      else
        "asc"
      end
    end

    def current_sort_field
      sort_config = default_sort_config
      return nil unless sort_config || params[:sort]

      params[:sort] || sort_config&.dig("field")
    end

    def current_sort_direction
      dir = params[:direction] || default_sort_config&.dig("direction") || "asc"
      %w[asc desc].include?(dir.to_s.downcase) ? dir.to_s.downcase : "asc"
    end

    def default_sort_config
      config = current_presenter&.index_config&.dig("default_sort")
      return config if config

      # Auto-default sort by position field when presenter is reorderable
      if current_presenter&.reorderable? && current_model_definition&.positioned?
        { "field" => current_model_definition.positioning_field, "direction" => "asc" }
      end
    end

    def compute_list_version_from_records(_records)
      return nil unless current_model_definition&.positioned?

      pos_field = current_model_definition.positioning_field
      # Use the model class directly instead of the records scope to avoid
      # inheriting search JOINs/WHERE clauses that can cause ambiguous column
      # errors (e.g., when both parent and child tables have a "title" column).
      ids_in_order = @model_class.order(pos_field => :asc).pluck(:id)
      Digest::SHA256.hexdigest(ids_in_order.join(","))
    end

    # -- Shared search, sort, and defaults --

    def apply_advanced_search(scope)
      search_config = current_presenter.search_config
      return scope unless search_config["enabled"]

      # 1. Apply default scope if configured (e.g., management presenters scoped by target_model)
      if search_config["default_scope"]
        scope_name = search_config["default_scope"]
        scope = scope.send(scope_name) if @model_class.respond_to?(scope_name)
      end

      # 2. Apply predefined filter scope (skipped when saved_filter is active)
      if params[:filter].present? && params[:saved_filter].blank?
        predefined = search_config["predefined_filters"]&.find { |f| f["name"] == params[:filter] }
        scope_name = predefined&.dig("scope")
        scope = scope.send(scope_name) if scope_name && @model_class.respond_to?(scope_name)
      end

      # 2.5a Apply saved filter (?saved_filter=<id>)
      if params[:saved_filter].present? && SavedFilters::Registry.available?
        result = apply_saved_filter(scope)
        if result
          scope = result[:scope]
          @active_saved_filter = result[:record]
          @saved_filter_warnings = result[:warnings]
        end
      end

      # 2.5b Apply parameterized scopes (?scope[name][param]=value)
      if params[:scope].present?
        scope_params = params[:scope].to_unsafe_h
        scope = Search::ParameterizedScopeApplicator.apply(
          scope, scope_params, @model_class, current_model_definition,
          evaluator: current_evaluator
        )
      end

      # 3. Sanitize ?f[...] params (reject blank values, enforce max_conditions)
      raw_filter_params = Search::ParamSanitizer.reject_blanks(params[:f]&.to_unsafe_h)
      max_conditions = current_presenter.advanced_filter_config["max_conditions"] || 10
      raw_filter_params = raw_filter_params&.first(max_conditions)&.to_h if raw_filter_params.is_a?(Hash) && raw_filter_params.size > max_conditions

      # 4. Intercept custom filter_* methods (before Ransack)
      if raw_filter_params.present?
        scope, remaining_params = Search::CustomFilterInterceptor.apply(
          scope, raw_filter_params, @model_class, current_evaluator
        )
      else
        remaining_params = {}
      end

      # 5. Ransack search (remaining params after custom filter interception)
      if remaining_params.present?
        @ransack_search = @model_class.ransack(remaining_params, auth_object: current_evaluator)
        scope = scope.merge(@ransack_search.result(distinct: true))
      end

      # 6. Quick text search (?qs=, additive, type-aware)
      searchable_fields = search_config["searchable_fields"]
      if params[:qs].present? && searchable_fields&.any?
        scope = Search::QuickSearch.apply(
          scope, params[:qs], @model_class, current_model_definition,
          searchable_field_names: searchable_fields
        )
      end

      # 7. Custom field filters (?cf[...])
      if params[:cf].present? && current_model_definition.custom_fields_enabled?
        scope = apply_custom_field_filters(scope)
      end

      scope
    end

    def apply_saved_filter(scope)
      model_class = SavedFilters::Registry.model_class
      return nil unless model_class

      record = model_class.find_by(id: params[:saved_filter])
      return nil unless record

      # Verify visibility access
      return nil unless saved_filter_visible?(record)

      # Validate condition tree against current filter metadata
      validation = SavedFilters::StaleFieldValidator.validate(
        record.condition_tree, filter_metadata
      )

      valid_tree = validation[:valid_tree]
      warnings = validation[:skipped_conditions]

      # Convert condition tree to Ransack params + scopes
      built = Search::FilterParamBuilder.build(valid_tree)
      ransack_params = built[:ransack] || {}
      cf_params = built[:custom_fields] || {}
      scope_params = built[:scopes] || {}

      # Apply scope params from the condition tree
      if scope_params.any?
        scope = Search::ParameterizedScopeApplicator.apply(
          scope, scope_params, @model_class, current_model_definition,
          evaluator: current_evaluator
        )
      end

      # Apply Ransack params
      if ransack_params.present?
        @ransack_search = @model_class.ransack(ransack_params, auth_object: current_evaluator)
        scope = scope.merge(@ransack_search.result(distinct: true))
      end

      # Apply custom field filters
      if cf_params.present? && current_model_definition.custom_fields_enabled?
        scope = apply_saved_filter_custom_fields(scope, cf_params)
      end

      { scope: scope, record: record, warnings: warnings }
    end

    def saved_filter_visible?(record)
      case record.visibility
      when "personal"
        record.owner_id == current_user&.id
      when "global"
        true
      when "role"
        user_roles = Array(current_user&.send(LcpRuby.configuration.role_method)).map(&:to_s)
        user_roles.include?(record.target_role.to_s)
      when "group"
        return false unless Groups::Registry.available?
        user_groups = Groups::Registry.groups_for_user(current_user&.id).map { |g|
          g.respond_to?(:name) ? g.name : g.to_s
        }
        user_groups.include?(record.target_group.to_s)
      else
        false
      end
    rescue StandardError
      false
    end

    def apply_saved_filter_custom_fields(scope, cf_params)
      definitions = CustomFields::Registry.for_model(current_model_definition.name)
      return scope if definitions.empty?

      filterable_defs = definitions.select { |d| d.active && d.respond_to?(:filterable) && d.filterable }
      defs_by_name = filterable_defs.index_by(&:field_name)
      sorted_names = defs_by_name.keys.sort_by { |n| -n.length }
      table_name = @model_class.table_name

      cf_params.each do |key, meta|
        field_name, operator = Search::CustomFieldFilter.parse_cf_key(key.delete_prefix("cf[").delete_suffix("]"), sorted_names)
        # Fallback: try using the full key as-is
        unless field_name
          cf_name = key.match(/\Acf\[(.+)\]\z/)&.captures&.first
          field_name = cf_name if cf_name && defs_by_name.key?(cf_name)
          operator = meta[:operator]
        end
        next unless field_name

        defn = defs_by_name[field_name]
        next unless defn
        next unless current_evaluator.field_readable?(field_name)

        cast = Search::CustomFieldFilter.cast_for_type(defn.custom_type)
        scope = Search::CustomFieldFilter.apply(scope, table_name, field_name, operator, meta[:value], cast: cast)
      end

      scope
    end

    def apply_custom_field_filters(scope)
      definitions = CustomFields::Registry.for_model(current_model_definition.name)
      return scope if definitions.empty?

      # Build lookup: field_name -> definition (active + filterable only)
      filterable_defs = definitions.select { |d| d.active && d.respond_to?(:filterable) && d.filterable }
      defs_by_name = filterable_defs.index_by(&:field_name)

      # Sort field names by length desc so longer names match first
      sorted_names = defs_by_name.keys.sort_by { |n| -n.length }
      table_name = @model_class.table_name

      params[:cf].each do |key, value|
        next if value.is_a?(String) && value.blank?

        field_name, operator = Search::CustomFieldFilter.parse_cf_key(key, sorted_names)
        next unless field_name

        defn = defs_by_name[field_name]
        next unless defn
        next unless current_evaluator.field_readable?(field_name)

        cast = Search::CustomFieldFilter.cast_for_type(defn.custom_type)
        scope = Search::CustomFieldFilter.apply(scope, table_name, field_name, operator, value, cast: cast)
      end

      scope
    end

    alias_method :apply_search, :apply_advanced_search

    def apply_sort(scope)
      sort_config = default_sort_config
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
        # Check if sort field is a virtual column — order by the subquery alias
        if current_model_definition.virtual_column(field.to_s)
          return scope.order(Arel.sql("#{@model_class.connection.quote_column_name(field)} #{direction}"))
        end

        return scope unless @model_class.column_names.include?(field.to_s)
        scope.order(field => direction)
      end
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

    # -- Error handlers --

    def user_not_authorized(exception = nil)
      log_authorization_denied(
        action: action_name,
        resource: @presenter_definition&.name || params[:lcp_slug],
        detail: exception&.message || "not authorized"
      )

      fallback = @presenter_definition ? resources_path : "/"
      respond_to do |format|
        format.html { redirect_to fallback, alert: "You are not authorized to perform this action." }
        format.json { render json: { error: "Not authorized" }, status: :forbidden }
        format.any { redirect_to fallback, alert: "You are not authorized to perform this action." }
      end
    end

    def metadata_error(exception)
      if LcpRuby.configuration.not_found_handler == :raise
        raise exception
      end

      respond_to do |format|
        format.html do
          render "lcp_ruby/errors/not_found",
                 status: :not_found,
                 locals: { message: I18n.t("lcp_ruby.errors.not_found_message", default: "The page you requested could not be found.") }
        end
        format.json { render json: { error: I18n.t("lcp_ruby.errors.not_found", default: "Not found") }, status: :not_found }
      end
    end

    def record_not_found(exception)
      if LcpRuby.configuration.not_found_handler == :raise
        raise exception
      end

      respond_to do |format|
        format.html do
          render "lcp_ruby/errors/not_found",
                 status: :not_found,
                 locals: { message: I18n.t("lcp_ruby.errors.record_not_found_message", default: "The record you requested could not be found.") }
        end
        format.json { render json: { error: I18n.t("lcp_ruby.errors.record_not_found", default: "Record not found") }, status: :not_found }
      end
    end

    def log_authorization_denied(action:, resource:, detail: nil)
      user_id = current_user&.id
      user_roles = begin
        current_evaluator&.roles
      rescue LcpRuby::MetadataError, Pundit::NotAuthorizedError
        nil
      end

      payload = {
        user_id: user_id,
        roles: user_roles,
        action: action,
        resource: resource,
        detail: detail,
        ip: request.remote_ip
      }

      Rails.logger.warn(
        "[LcpRuby::Auth] Access denied: user=#{user_id} roles=#{user_roles&.join(',')}" \
        " action=#{action} resource=#{resource} detail=#{detail}"
      )

      ActiveSupport::Notifications.instrument("authorization.lcp_ruby", payload)
    end
  end
end
