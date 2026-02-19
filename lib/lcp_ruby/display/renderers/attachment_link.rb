module LcpRuby
  module Display
    module Renderers
      class AttachmentLink < BaseRenderer
        include Concerns::AttachmentHelpers

        def render(value, options = {}, record: nil, view_context: nil)
          attachment = resolve_attachment(value, record)
          return view_context.content_tag(:span, I18n.t("lcp_ruby.file_upload.no_file", default: "No file"), class: "lcp-no-attachment") unless attachment_present?(attachment)

          att = attachment.respond_to?(:blob) ? attachment : attachment.first
          return view_context.content_tag(:span, I18n.t("lcp_ruby.file_upload.no_file", default: "No file"), class: "lcp-no-attachment") unless att&.respond_to?(:blob)

          view_context.link_to(att.blob.filename.to_s, attachment_url(att), target: "_blank", rel: "noopener", class: "lcp-attachment-download")
        rescue StandardError
          view_context.content_tag(:span, "Download", class: "lcp-attachment-download")
        end
      end
    end
  end
end
