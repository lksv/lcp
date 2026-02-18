module LcpRuby
  class ApplicationController < LcpRuby.configuration.parent_controller.constantize
    include Pundit::Authorization

    helper LcpRuby::DisplayHelper
    helper LcpRuby::FormHelper
    helper LcpRuby::LayoutHelper
    helper LcpRuby::ConditionHelper

    layout "lcp_ruby/application"

    before_action :authenticate_user!
    before_action :set_presenter_and_model
    before_action :authorize_presenter_access

    helper_method :current_presenter, :current_model_definition, :current_evaluator,
                  :resource_path, :resources_path, :new_resource_path, :edit_resource_path,
                  :single_action_path,
                  :toggle_direction,
                  :current_view_group, :sibling_views

    rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
    rescue_from LcpRuby::MetadataError, with: :metadata_error

    private

    def authenticate_user!
      # Host app must override this or provide current_user
      raise "Host app must implement authentication" unless current_user
      LcpRuby::Current.user = current_user
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
        Authorization::PermissionEvaluator.new(perm_def, current_user, @presenter_definition.model)
      end
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

    # -- View helpers --

    def toggle_direction(field)
      if params[:sort] == field && params[:direction] == "asc"
        "desc"
      else
        "asc"
      end
    end

    # -- Error handlers --

    def user_not_authorized
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
  end
end
