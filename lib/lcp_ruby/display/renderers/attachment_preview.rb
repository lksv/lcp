module LcpRuby
  module Display
    module Renderers
      class AttachmentPreview < BaseRenderer
        include Concerns::AttachmentHelpers

        def render(value, options = {}, record: nil, view_context: nil)
          attachment = resolve_attachment(value, record)
          return view_context.content_tag(:span, I18n.t("lcp_ruby.file_upload.no_file", default: "No file"), class: "lcp-no-attachment") unless attachment_present?(attachment)

          if single_attachment?(attachment)
            render_single_preview(attachment, options, view_context: view_context)
          else
            view_context.content_tag(:div, class: "lcp-attachment-preview") do
              view_context.safe_join(attachment.map { |att| render_single_preview(att, options, view_context: view_context) })
            end
          end
        end
      end
    end
  end
end
