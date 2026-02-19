module LcpRuby
  module Display
    module Renderers
      module Concerns
        module AttachmentHelpers
          private

          def resolve_attachment(value, record)
            value
          end

          def attachment_url(att)
            Rails.application.routes.url_helpers.rails_blob_path(att, only_path: true)
          end

          def variant_url(variant)
            Rails.application.routes.url_helpers.rails_representation_path(variant, only_path: true)
          end

          def attachment_present?(attachment)
            return false if attachment.nil?
            return attachment.attached? if attachment.respond_to?(:attached?)
            return attachment.any? { |a| a.respond_to?(:blob) } if attachment.respond_to?(:any?)
            attachment.respond_to?(:blob)
          end

          def single_attachment?(attachment)
            attachment.respond_to?(:blob)
          end

          def render_single_preview(attachment, options, view_context:)
            blob = attachment.respond_to?(:blob) ? attachment.blob : attachment
            variant_name = options["variant"]

            if blob.image?
              img = render_image_variant(attachment, blob, variant_name, view_context: view_context)
              view_context.content_tag(:div, img, class: "lcp-attachment-preview-item")
            else
              view_context.link_to(blob.filename.to_s, attachment_url(attachment), target: "_blank", rel: "noopener", class: "lcp-attachment-download")
            end
          rescue StandardError => e
            Rails.logger.error("[LcpRuby] render_single_preview error: #{e.class}: #{e.message}")
            view_context.content_tag(:span, blob&.filename.to_s || "File", class: "lcp-attachment-download")
          end

          def render_image_variant(attachment, blob, variant_name, view_context:)
            if variant_name && image_processing_available? && attachment.respond_to?(:variant)
              model_class = attachment.record.class
              variants = model_class.respond_to?(:lcp_attachment_variants) ? model_class.lcp_attachment_variants : {}
              field_variants = variants[attachment.name.to_s] || {}
              variant_config = field_variants[variant_name.to_s]

              if variant_config
                begin
                  return view_context.image_tag(variant_url(attachment.variant(variant_config.transform_keys(&:to_sym))),
                    class: "lcp-attachment-image", alt: blob.filename.to_s)
                rescue StandardError
                  # Variant processing failed, fall back to original image
                end
              end
            end

            view_context.image_tag(attachment_url(attachment), class: "lcp-attachment-image", alt: blob.filename.to_s)
          end

          def image_processing_available?
            defined?(ImageProcessing)
          end
        end
      end
    end
  end
end
