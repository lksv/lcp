module LcpRuby
  class CustomFieldsController < ApplicationController
    rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

    # Reuse resources views (index, show, new, edit, _form, etc.)
    def self.controller_path
      "lcp_ruby/resources"
    end

    before_action :verify_custom_fields_enabled
    before_action :set_record, only: [ :show, :edit, :update, :destroy ]

    def index
      authorize @cfd_model_class
      scope = policy_scope(@cfd_model_class).where(target_model: @parent_model_definition.name)
      scope = apply_search(scope)
      scope = apply_sort(scope)

      @records = scope.page(params[:page]).per(current_presenter.per_page)

      @column_set = Presenter::ColumnSet.new(current_presenter, current_evaluator)
      @fk_map = {}
      @action_set = Presenter::ActionSet.new(current_presenter, current_evaluator)
      @field_resolver = Presenter::FieldValueResolver.new(current_model_definition, current_evaluator)
    end

    def show
      authorize @record
      @layout_builder = Presenter::LayoutBuilder.new(current_presenter, current_model_definition)
      @column_set = Presenter::ColumnSet.new(current_presenter, current_evaluator)
      @action_set = Presenter::ActionSet.new(current_presenter, current_evaluator)
      @field_resolver = Presenter::FieldValueResolver.new(current_model_definition, current_evaluator)
    end

    def new
      @record = @cfd_model_class.new(target_model: @parent_model_definition.name)
      authorize @record
      apply_presenter_defaults(@record)
      @layout_builder = Presenter::LayoutBuilder.new(current_presenter, current_model_definition)
    end

    def create
      @record = @cfd_model_class.new(permitted_params)
      @record.target_model = @parent_model_definition.name
      authorize @record

      if @record.save
        redirect_to custom_fields_show_path, notice: "Custom field was successfully created."
      else
        @layout_builder = Presenter::LayoutBuilder.new(current_presenter, current_model_definition)
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize @record
      @layout_builder = Presenter::LayoutBuilder.new(current_presenter, current_model_definition)
    end

    def update
      authorize @record
      @record.assign_attributes(permitted_params)
      # Prevent target_model tampering
      @record.target_model = @parent_model_definition.name

      if @record.save
        redirect_to custom_fields_show_path, notice: "Custom field was successfully updated."
      else
        @layout_builder = Presenter::LayoutBuilder.new(current_presenter, current_model_definition)
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize @record
      @record.destroy!
      redirect_to custom_fields_index_path, notice: "Custom field was successfully deleted."
    rescue ActiveRecord::RecordNotDestroyed => e
      redirect_to resource_path(@record), alert: "Could not delete custom field: #{e.record.errors.full_messages.join(', ')}"
    end

    private

    # Override ApplicationController#set_presenter_and_model to set up dual context:
    # - Parent: resolved from :lcp_slug (e.g., "projects" -> project model)
    # - CFD: custom_field_definition model + BuiltInPresenter
    def set_presenter_and_model
      slug = params[:lcp_slug]
      return unless slug

      # Resolve the parent context from the URL slug
      parent_presenter = begin
        Presenter::Resolver.find_by_slug(slug)
      rescue MetadataError
        raise ActiveRecord::RecordNotFound, "No presenter found for slug '#{slug}'"
      end
      @parent_model_definition = LcpRuby.loader.model_definition(parent_presenter.model)

      # Set up CFD presenter and model as the "current" context for views
      @presenter_definition = CustomFields::BuiltInPresenter.presenter_definition(
        target_model: @parent_model_definition.name
      )
      @cfd_model_definition = LcpRuby.loader.model_definition("custom_field_definition")
      @model_definition = @cfd_model_definition
      @cfd_model_class = LcpRuby.registry.model_for("custom_field_definition")
      @model_class = @cfd_model_class
    end

    def authorize_presenter_access
      # Custom fields access is governed by CFD permissions, not parent presenter access.
      # The verify_custom_fields_enabled check ensures the parent model supports custom fields.
    end

    def verify_custom_fields_enabled
      unless @parent_model_definition&.custom_fields_enabled?
        raise MetadataError, "Custom fields are not enabled for '#{params[:lcp_slug]}'"
      end
    end

    def set_record
      @record = @cfd_model_class.where(target_model: @parent_model_definition.name).find(params[:id])
    end

    def current_evaluator
      @current_evaluator ||= begin
        perm_def = LcpRuby.loader.permission_definition("custom_field_definition")
        user = impersonating? ? impersonated_user : current_user
        Authorization::PermissionEvaluator.new(perm_def, user, "custom_field_definition")
      end
    end

    # -- Path helpers (override to use custom_fields named routes) --

    def resource_path(record)
      lcp_ruby.custom_fields_show_path(lcp_slug: params[:lcp_slug], id: record.respond_to?(:id) ? record.id : record)
    end

    def resources_path
      lcp_ruby.custom_fields_path(lcp_slug: params[:lcp_slug])
    end

    def new_resource_path
      lcp_ruby.custom_fields_new_path(lcp_slug: params[:lcp_slug])
    end

    def edit_resource_path(record)
      lcp_ruby.custom_fields_edit_path(lcp_slug: params[:lcp_slug], id: record.respond_to?(:id) ? record.id : record)
    end

    def single_action_path(record, action_name:)
      # Custom fields don't support custom actions; return nil
      nil
    end

    def select_options_path
      nil
    end

    # -- Pundit --

    def policy(record)
      policy_class = Authorization::PolicyFactory.policy_for("custom_field_definition")
      policy_class.new(current_user, record)
    end

    def policy_scope(scope)
      policy_class = Authorization::PolicyFactory.policy_for("custom_field_definition")
      policy_class::Scope.new(current_user, scope).resolve
    end

    def authorize(record, query = nil)
      pol = policy(record)
      query ||= "#{action_name}?"
      raise Pundit::NotAuthorizedError unless pol.public_send(query)
    end

    # -- Private path helpers for redirects --

    def custom_fields_index_path
      lcp_ruby.custom_fields_path(lcp_slug: params[:lcp_slug])
    end

    def custom_fields_show_path
      lcp_ruby.custom_fields_show_path(lcp_slug: params[:lcp_slug], id: @record.id)
    end

    # -- Permitted params --

    def permitted_params
      writable = current_evaluator.writable_fields.map(&:to_sym)
      # Exclude target_model from permitted params (set from URL context)
      writable -= [ :target_model ]
      params.require(:record).permit(*writable)
    end

    # -- Error handlers --

    def record_not_found
      respond_to do |format|
        format.html { render plain: "Record not found", status: :not_found }
        format.json { render json: { error: "Not found" }, status: :not_found }
        format.any { head :not_found }
      end
    end

    # -- Breadcrumbs --

    def breadcrumbs
      return @breadcrumbs if defined?(@breadcrumbs)

      @breadcrumbs = []
      @breadcrumbs << Presenter::BreadcrumbBuilder::Crumb.new(
        label: I18n.t("lcp_ruby.breadcrumbs.home", default: "Home"),
        path: LcpRuby.configuration.breadcrumb_home_path
      )

      parent_presenter = Presenter::Resolver.find_by_slug(params[:lcp_slug])
      @breadcrumbs << Presenter::BreadcrumbBuilder::Crumb.new(
        label: parent_presenter.label,
        path: lcp_ruby.resources_path(lcp_slug: params[:lcp_slug])
      )

      @breadcrumbs << Presenter::BreadcrumbBuilder::Crumb.new(
        label: "Custom Fields",
        path: resources_path
      )

      if @record&.persisted?
        @breadcrumbs << Presenter::BreadcrumbBuilder::Crumb.new(
          label: @record.respond_to?(:to_label) ? @record.to_label : @record.to_s,
          path: resource_path(@record)
        )
      end

      if %w[edit new].include?(action_name)
        @breadcrumbs << Presenter::BreadcrumbBuilder::Crumb.new(
          label: I18n.t("lcp_ruby.breadcrumbs.#{action_name}", default: action_name.humanize)
        )
      end

      @breadcrumbs.last.current = true if @breadcrumbs.any?
      @breadcrumbs
    rescue => e
      raise unless Rails.env.production?
      Rails.logger.error(
        "[LcpRuby::Breadcrumbs] Failed to build breadcrumbs: #{e.class}: #{e.message} " \
        "(controller=#{self.class.name}, slug=#{params[:lcp_slug]}, action=#{action_name}, record_id=#{@record&.id})"
      )
      @breadcrumbs = []
    end
  end
end
