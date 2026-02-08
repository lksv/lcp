module LcpRuby
  class ActionsController < ApplicationController
    def execute_single
      record = @model_class.find(params[:id])
      action_key = "#{current_presenter.model}/#{params[:action_name]}"

      unless current_evaluator.can_execute_action?(params[:action_name])
        raise Pundit::NotAuthorizedError, "not allowed to execute action #{params[:action_name]}"
      end

      result = Actions::ActionExecutor.new(action_key, {
        record: record,
        current_user: current_user,
        params: action_params,
        model_class: @model_class
      }).execute

      handle_result(result)
    end

    def execute_collection
      action_key = "#{current_presenter.model}/#{params[:action_name]}"

      unless current_evaluator.can_execute_action?(params[:action_name])
        raise Pundit::NotAuthorizedError, "not allowed to execute action #{params[:action_name]}"
      end

      result = Actions::ActionExecutor.new(action_key, {
        current_user: current_user,
        params: action_params,
        model_class: @model_class
      }).execute

      handle_result(result)
    end

    def execute_batch
      ids = params[:ids] || []
      records = @model_class.where(id: ids)
      action_key = find_batch_action_key

      unless current_evaluator.can_execute_action?(params[:action_name])
        raise Pundit::NotAuthorizedError, "not allowed to execute action #{params[:action_name]}"
      end

      result = Actions::ActionExecutor.new(action_key, {
        records: records,
        current_user: current_user,
        params: action_params,
        model_class: @model_class
      }).execute

      handle_result(result)
    end

    private

    def action_params
      params.fetch(:action_params, {}).permit!
    end

    def find_batch_action_key
      batch_action = current_presenter.batch_actions.find do |a|
        a = a.transform_keys(&:to_s) if a.is_a?(Hash)
        a["name"] == params[:action_name]
      end

      if batch_action
        action_class_key = batch_action.is_a?(Hash) ? batch_action["action_class"] : nil
        action_class_key || "#{current_presenter.model}/#{params[:action_name]}"
      else
        "#{current_presenter.model}/#{params[:action_name]}"
      end
    end

    def handle_result(result)
      respond_to do |format|
        if result.success?
          if result.data&.dig(:csv)
            format.html {
              send_data result.data[:csv],
                filename: result.data[:filename] || "export.csv",
                type: "text/csv"
            }
          else
            format.html { redirect_back(fallback_location: root_path, notice: result.message) }
          end
          format.json { render json: { success: true, message: result.message, data: result.data } }
        else
          format.html { redirect_back(fallback_location: root_path, alert: result.message) }
          format.json { render json: { success: false, message: result.message, errors: result.errors }, status: :unprocessable_entity }
        end
      end
    end
  end
end
