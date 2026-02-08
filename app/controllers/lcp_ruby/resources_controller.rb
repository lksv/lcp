module LcpRuby
  class ResourcesController < ApplicationController
    before_action :set_record, only: [:show, :edit, :update, :destroy]

    def index
      authorize @model_class
      scope = policy_scope(@model_class)
      scope = apply_search(scope)
      scope = apply_sort(scope)
      @records = scope.page(params[:page]).per(current_presenter.per_page)

      @column_set = Presenter::ColumnSet.new(current_presenter, current_evaluator)
      @action_set = Presenter::ActionSet.new(current_presenter, current_evaluator)
    end

    def show
      authorize @record
      @layout_builder = Presenter::LayoutBuilder.new(current_presenter, current_model_definition)
      @column_set = Presenter::ColumnSet.new(current_presenter, current_evaluator)
      @action_set = Presenter::ActionSet.new(current_presenter, current_evaluator)
    end

    def new
      @record = @model_class.new
      authorize @record
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

    private

    def set_record
      @record = @model_class.find(params[:id])
    end

    def permitted_params
      writable = current_evaluator.writable_fields.map(&:to_sym)

      # Also permit belongs_to foreign keys
      fk_fields = current_model_definition.associations
        .select { |a| a.type == "belongs_to" && a.foreign_key.present? }
        .map { |a| a.foreign_key.to_sym }

      params.require(:record).permit(*(writable + fk_fields).uniq)
    end

    def apply_search(scope)
      search_config = current_presenter.search_config
      return scope unless search_config["enabled"]

      if params[:filter].present?
        predefined = search_config["predefined_filters"]&.find { |f| f["name"] == params[:filter] }
        scope = scope.send(predefined["scope"]) if predefined&.dig("scope")
      end

      if params[:q].present?
        searchable = search_config["searchable_fields"] || []
        conditions = searchable.map { |f| "#{f} LIKE :q" }.join(" OR ")
        scope = scope.where(conditions, q: "%#{params[:q]}%") if conditions.present?
      end

      scope
    end

    def apply_sort(scope)
      sort_config = current_presenter.index_config["default_sort"]
      return scope unless sort_config

      field = params[:sort] || sort_config["field"]
      direction = params[:direction] || sort_config["direction"] || "asc"
      direction = "asc" unless %w[asc desc].include?(direction.to_s.downcase)

      scope.order(field => direction)
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
