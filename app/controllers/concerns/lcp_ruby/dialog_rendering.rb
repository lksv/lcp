module LcpRuby
  module DialogRendering
    extend ActiveSupport::Concern

    def dialog_context?
      params[:_dialog].present? || is_a?(LcpRuby::DialogsController)
    end

    def render_dialog_form(status: :ok)
      @layout_builder = Presenter::LayoutBuilder.new(current_presenter, current_model_definition)
      render html: render_to_string(
        partial: "lcp_ruby/dialogs/dialog_frame",
        locals: dialog_locals
      ).html_safe, layout: false, status: status
    end

    def render_dialog_success(on_success = "reload")
      render html: render_to_string(
        partial: "lcp_ruby/dialogs/success",
        locals: { on_success: on_success }
      ).html_safe, layout: false
    end

    def render_dialog_form_with_errors
      render_dialog_form(status: :unprocessable_content)
    end

    def dialog_locals
      {
        record: @record,
        page: resolved_dialog_page,
        dialog_config: resolved_dialog_config,
        presenter: current_presenter,
        model_definition: current_model_definition,
        layout_builder: @layout_builder
      }
    end

    def resolved_dialog_page
      @page_definition || current_page
    end

    # Merges page dialog defaults with action-level overrides from params.
    # Priority: action override (params) > page config > system defaults.
    def resolved_dialog_config
      page = resolved_dialog_page
      base = {
        "size" => page.dialog_size,
        "closable" => page.dialog_closable?,
        "title_key" => page.dialog_title_key
      }

      # Action-level overrides passed via query params (allowlisted keys only)
      allowed_keys = %w[size closable title_key]
      overrides = (params[:dialog_config]&.permit(*allowed_keys)&.to_h || {})
      base.merge(overrides).compact
    end

    def dialog_form_url
      if is_a?(LcpRuby::DialogsController)
        page_name = params[:page_name]
        if @record.respond_to?(:persisted?) && @record.persisted?
          lcp_ruby.dialog_update_path(page_name: page_name, id: @record.id)
        else
          lcp_ruby.dialog_create_path(page_name: page_name)
        end
      else
        if @record.respond_to?(:new_record?) && @record.new_record?
          resources_path
        else
          resource_path(@record)
        end
      end
    end

    def defaults_from_params
      return {} unless params[:defaults].present?

      allowed = current_model_definition.fields.map(&:name)
      params[:defaults].permit(*allowed).to_h
    end
  end
end
