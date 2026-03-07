module LcpRuby
  class SavedFiltersController < ApplicationController
    include DialogRendering

    before_action :verify_saved_filters_available
    before_action :set_saved_filter, only: [ :update, :destroy ]

    # GET /:lcp_slug/saved-filters
    # Returns visible saved filters for the current user and presenter.
    def index
      authorize_index!
      filters = SavedFilters::Resolver.visible_filters(
        presenter_slug: current_presenter.slug,
        user: current_user,
        evaluator: current_evaluator
      )

      render json: filters.map { |f| serialize_filter(f) }
    end

    # POST /:lcp_slug/saved-filters
    # Creates a new saved filter.
    def create
      return create_from_dialog if dialog_context?

      authorize_create!
      model_class = SavedFilters::Registry.model_class

      record = model_class.new(saved_filter_params)
      record.owner_id = current_user.id
      record.target_presenter = current_presenter.slug

      # Generate QL text from condition tree
      if record.respond_to?(:ql_text=) && record.condition_tree.present?
        record.ql_text = Search::QueryLanguageSerializer.serialize(record.condition_tree)
      end

      # Enforce limits
      limit_error = check_limits(record)
      if limit_error
        render json: { error: limit_error }, status: :unprocessable_content
        return
      end

      if record.save
        render json: serialize_filter(record), status: :created
      else
        render json: { errors: record.errors.full_messages }, status: :unprocessable_content
      end
    end

    # PATCH /:lcp_slug/saved-filters/:id
    # Updates an existing saved filter.
    def update
      authorize_modify!(@saved_filter)

      @saved_filter.assign_attributes(saved_filter_params)

      # Regenerate QL text
      if @saved_filter.respond_to?(:ql_text=) && @saved_filter.condition_tree.present?
        @saved_filter.ql_text = Search::QueryLanguageSerializer.serialize(@saved_filter.condition_tree)
      end

      if @saved_filter.save
        render json: serialize_filter(@saved_filter)
      else
        render json: { errors: @saved_filter.errors.full_messages }, status: :unprocessable_content
      end
    end

    # DELETE /:lcp_slug/saved-filters/:id
    # Deletes a saved filter.
    def destroy
      authorize_modify!(@saved_filter)
      @saved_filter.destroy!
      render json: { success: true }
    end

    private

    def create_from_dialog
      authorize_create!
      model_class = SavedFilters::Registry.model_class

      record = model_class.new(saved_filter_params)
      record.owner_id = current_user.id
      record.target_presenter = current_presenter.slug

      if record.respond_to?(:ql_text=) && record.condition_tree.present?
        record.ql_text = Search::QueryLanguageSerializer.serialize(record.condition_tree)
      end

      limit_error = check_limits(record)
      if limit_error
        render json: { error: limit_error }, status: :unprocessable_content
        return
      end

      if record.save
        render_dialog_success("reload")
      else
        render json: { errors: record.errors.full_messages }, status: :unprocessable_content
      end
    end

    def verify_saved_filters_available
      unless SavedFilters::Registry.available?
        render json: { error: "Saved filters not available" }, status: :not_found
      end
    end

    def set_saved_filter
      model_class = SavedFilters::Registry.model_class
      @saved_filter = model_class.find(params[:id])

      # Verify it belongs to this presenter
      unless @saved_filter.target_presenter == current_presenter.slug
        raise ActiveRecord::RecordNotFound
      end
    end

    def saved_filter_params
      allowed = %i[name description visibility target_role target_group
                   position icon color pinned default_filter]
      result = params.require(:saved_filter).permit(*allowed)

      # condition_tree can arrive as a JSON string or a nested hash
      raw_tree = params[:saved_filter][:condition_tree]
      if raw_tree.present?
        result[:condition_tree] = raw_tree.is_a?(String) ? JSON.parse(raw_tree) : raw_tree.to_unsafe_h
      end

      result
    end

    def authorize_index!
      # Users with read access to the presenter can list saved filters
      raise Pundit::NotAuthorizedError unless current_evaluator.can?(:index)
    end

    def authorize_create!
      raise Pundit::NotAuthorizedError unless current_evaluator.can?(:index)

      # Check saved_filter specific permissions if available
      if has_saved_filter_permissions?
        sf_evaluator = saved_filter_evaluator
        raise Pundit::NotAuthorizedError unless sf_evaluator.can?(:create)
      end
    end

    def authorize_modify!(record)
      # Owner can always modify their own personal filters
      if record.visibility == "personal" && record.owner_id == current_user.id
        return
      end

      # For non-personal filters, check saved_filter permissions
      if has_saved_filter_permissions?
        sf_evaluator = saved_filter_evaluator
        raise Pundit::NotAuthorizedError unless sf_evaluator.can?(:update)
      else
        # Without specific permissions, only the owner can modify
        raise Pundit::NotAuthorizedError unless record.owner_id == current_user.id
      end
    end

    def has_saved_filter_permissions?
      LcpRuby.loader.permission_definitions.key?("saved_filter")
    rescue LcpRuby::MetadataError
      false
    end

    def saved_filter_evaluator
      perm_def = LcpRuby.loader.permission_definition("saved_filter")
      Authorization::PermissionEvaluator.new(perm_def, current_user, "saved_filter")
    end

    def check_limits(record)
      model_class = SavedFilters::Registry.model_class
      sf_config = current_presenter.saved_filters_config
      presenter_slug = current_presenter.slug

      case record.visibility
      when "personal"
        max = sf_config["max_per_user"] || 50
        count = model_class.where(
          target_presenter: presenter_slug, visibility: "personal", owner_id: current_user.id
        ).count
        return I18n.t("lcp_ruby.saved_filters.limit_reached", default: "Maximum number of filters reached") if count >= max
      when "role"
        max = sf_config["max_per_role"] || 20
        count = model_class.where(
          target_presenter: presenter_slug, visibility: "role", target_role: record.target_role
        ).count
        return I18n.t("lcp_ruby.saved_filters.limit_reached", default: "Maximum number of filters reached") if count >= max
      when "global"
        max = sf_config["max_global"] || 30
        count = model_class.where(
          target_presenter: presenter_slug, visibility: "global"
        ).count
        return I18n.t("lcp_ruby.saved_filters.limit_reached", default: "Maximum number of filters reached") if count >= max
      end

      nil
    end

    def serialize_filter(filter)
      {
        id: filter.id,
        name: filter.name,
        description: filter.respond_to?(:description) ? filter.description : nil,
        visibility: filter.visibility,
        target_role: filter.respond_to?(:target_role) ? filter.target_role : nil,
        target_group: filter.respond_to?(:target_group) ? filter.target_group : nil,
        pinned: filter.respond_to?(:pinned) ? filter.pinned : false,
        default_filter: filter.respond_to?(:default_filter) ? filter.default_filter : false,
        icon: filter.respond_to?(:icon) ? filter.icon : nil,
        color: filter.respond_to?(:color) ? filter.color : nil,
        ql_text: filter.respond_to?(:ql_text) ? filter.ql_text : nil,
        owner_id: filter.owner_id,
        is_owner: filter.owner_id == current_user&.id
      }
    end
  end
end
