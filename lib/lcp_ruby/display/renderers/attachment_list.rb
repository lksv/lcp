module LcpRuby
  module Display
    module Renderers
      class AttachmentList < BaseRenderer
        include Concerns::AttachmentHelpers

        def render(value, options = {}, record: nil, view_context: nil)
          attachment = resolve_attachment(value, record)
          return view_context.content_tag(:span, I18n.t("lcp_ruby.file_upload.no_file", default: "No file"), class: "lcp-no-attachment") unless attachment_present?(attachment)

          items = attachment.respond_to?(:each) ? attachment.to_a : [ attachment ]
          view_context.content_tag(:ul, class: "lcp-attachment-list") do
            view_context.safe_join(items.select { |att| att.respond_to?(:blob) }.map { |att|
              view_context.content_tag(:li) do
                view_context.link_to(att.blob.filename.to_s, attachment_url(att), target: "_blank", rel: "noopener") +
                  " " +
                  view_context.content_tag(:span, "(#{view_context.number_to_human_size(att.blob.byte_size)})", class: "lcp-attachment-size")
              end
            })
          end
        rescue StandardError
          view_context.content_tag(:span, "Attachments", class: "lcp-attachment-list")
        end
      end
    end
  end
end
