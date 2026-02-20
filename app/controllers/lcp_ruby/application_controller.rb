module LcpRuby
  class ApplicationController < LcpRuby.configuration.parent_controller.constantize
    include Pundit::Authorization

    helper LcpRuby::DisplayHelper
    helper LcpRuby::DisplayTemplateHelper
    helper LcpRuby::FormHelper
    helper LcpRuby::LayoutHelper
    helper LcpRuby::ConditionHelper

    layout "lcp_ruby/application"

    before_action :authenticate_user!
    before_action :set_presenter_and_model
    before_action :authorize_presenter_access

    helper_method :current_presenter, :current_model_definition, :current_evaluator,
                  :resource_path, :resources_path, :new_resource_path, :edit_resource_path,
                  :single_action_path, :select_options_path,
                  :toggle_direction, :current_sort_field, :current_sort_direction,
                  :current_view_group, :sibling_views,
                  :impersonating?, :impersonated_role, :available_roles_for_impersonation,
                  :breadcrumbs

    rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
    rescue_from LcpRuby::MetadataError, with: :metadata_error

    private

    def authenticate_user!
      # Public view groups allow unauthenticated access
      if current_request_public?
        LcpRuby::Current.user = current_user || anonymous_user
        return
      end

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

    def current_evaluator
      @current_evaluator ||= begin
        perm_def = LcpRuby.loader.permission_definition(@presenter_definition.model)
        user = impersonating? ? impersonated_user : current_user
        Authorization::PermissionEvaluator.new(perm_def, user, @presenter_definition.model)
      end
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

    def select_options_path
      lcp_ruby.select_options_path(lcp_slug: current_presenter.slug)
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
      current_presenter&.index_config&.dig("default_sort")
    end

    # -- Shared search, sort, and defaults --

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
      respond_to do |format|
        format.html { render plain: "Configuration error: #{exception.message}", status: :internal_server_error }
        format.json { render json: { error: exception.message }, status: :internal_server_error }
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
