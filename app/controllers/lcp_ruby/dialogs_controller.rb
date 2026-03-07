module LcpRuby
  class DialogsController < ApplicationController
    include DialogRendering

    skip_before_action :set_presenter_and_model
    before_action :set_dialog_presenter_and_model

    def new
      if virtual_model?
        @record = JsonItemWrapper.new(defaults_from_params, @model_definition)
      else
        @record = @model_class.new(defaults_from_params)
      end

      render_dialog_form
    end

    def create
      if virtual_model?
        @record = JsonItemWrapper.new(dialog_permitted_params, @model_definition)
        @record.validate_with_model_rules!

        if @record.errors.none?
          dispatch_virtual_model_action
          render_dialog_success(dialog_on_success)
        else
          render_dialog_form_with_errors
        end
      else
        @record = @model_class.new(dialog_permitted_params)
        authorize @record

        if @record.save
          render_dialog_success(dialog_on_success)
        else
          render_dialog_form_with_errors
        end
      end
    end

    def edit
      @record = @model_class.find(params[:id])
      authorize @record

      render_dialog_form
    end

    def update
      @record = @model_class.find(params[:id])
      authorize @record
      @record.assign_attributes(dialog_permitted_params)

      if @record.save
        render_dialog_success(dialog_on_success)
      else
        render_dialog_form_with_errors
      end
    end

    private

    def set_dialog_presenter_and_model
      page_name = params[:page_name]
      @page_definition = Pages::Resolver.find_by_name(page_name)
      @presenter_definition = LcpRuby.loader.presenter_definition(@page_definition.main_presenter_name)
      @model_definition = LcpRuby.loader.model_definition(@presenter_definition.model)

      if @model_definition.virtual?
        @model_class = nil
      else
        @model_class = LcpRuby.registry.model_for(@presenter_definition.model)
      end
    end

    def virtual_model?
      @model_definition.virtual?
    end

    def dialog_permitted_params
      if virtual_model?
        allowed = @model_definition.fields.map(&:name)
        return params.fetch(:record, {}).to_unsafe_h.stringify_keys.slice(*allowed)
      end

      writable_fields = current_evaluator.writable_fields
      field_names = @model_definition.fields
        .select { |f| writable_fields.include?(f.name) }
        .map { |f| f.name.to_sym }

      # Include FK fields for associations
      fk_fields = @model_definition.associations
        .select { |a| a.type == "belongs_to" && a.foreign_key }
        .map { |a| a.foreign_key.to_sym }

      params.require(:record).permit(*(field_names + fk_fields))
    end

    def dialog_on_success
      params[:on_success] || "reload"
    end

    def dispatch_virtual_model_action
      Events::Dispatcher.dispatch(
        event_name: "dialog_submit",
        record: @record
      )
    end
  end
end
