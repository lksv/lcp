module LcpRuby
  module Display
    class RendererRegistry
      BUILT_IN_RENDERERS = {
        "heading"            => "LcpRuby::Display::Renderers::Heading",
        "badge"              => "LcpRuby::Display::Renderers::Badge",
        "collection"         => "LcpRuby::Display::Renderers::Collection",
        "truncate"           => "LcpRuby::Display::Renderers::Truncate",
        "boolean_icon"       => "LcpRuby::Display::Renderers::BooleanIcon",
        "progress_bar"       => "LcpRuby::Display::Renderers::ProgressBar",
        "image"              => "LcpRuby::Display::Renderers::Image",
        "avatar"             => "LcpRuby::Display::Renderers::Avatar",
        "currency"           => "LcpRuby::Display::Renderers::Currency",
        "percentage"         => "LcpRuby::Display::Renderers::Percentage",
        "number"             => "LcpRuby::Display::Renderers::Number",
        "date"               => "LcpRuby::Display::Renderers::Date",
        "datetime"           => "LcpRuby::Display::Renderers::Datetime",
        "relative_date"      => "LcpRuby::Display::Renderers::RelativeDate",
        "email_link"         => "LcpRuby::Display::Renderers::EmailLink",
        "phone_link"         => "LcpRuby::Display::Renderers::PhoneLink",
        "url_link"           => "LcpRuby::Display::Renderers::UrlLink",
        "color_swatch"       => "LcpRuby::Display::Renderers::ColorSwatch",
        "rating"             => "LcpRuby::Display::Renderers::Rating",
        "code"               => "LcpRuby::Display::Renderers::Code",
        "file_size"          => "LcpRuby::Display::Renderers::FileSize",
        "rich_text"          => "LcpRuby::Display::Renderers::RichText",
        "attachment_preview" => "LcpRuby::Display::Renderers::AttachmentPreview",
        "attachment_list"    => "LcpRuby::Display::Renderers::AttachmentList",
        "attachment_link"    => "LcpRuby::Display::Renderers::AttachmentLink",
        "link"               => "LcpRuby::Display::Renderers::Link"
      }.freeze

      class << self
        def renderer_for(key)
          registry[key.to_s]
        end

        def register(key, renderer_class)
          registry[key.to_s] = renderer_class.new
        end

        def registered?(key)
          registry.key?(key.to_s)
        end

        def register_built_ins!
          BUILT_IN_RENDERERS.each do |key, class_name|
            register(key, class_name.constantize)
          rescue NameError => e
            Rails.logger.warn("[LcpRuby] Could not register built-in renderer #{class_name}: #{e.message}")
          end
        end

        def discover!(base_path)
          renderers_path = File.join(base_path, "renderers")
          return unless File.directory?(renderers_path)

          Dir[File.join(renderers_path, "**", "*.rb")].sort.each do |file|
            require file

            relative = file.sub("#{renderers_path}/", "").sub(/\.rb$/, "")
            class_name = "LcpRuby::HostRenderers::#{relative.split('/').map(&:camelize).join('::')}"

            begin
              renderer_class = class_name.constantize
              register(relative, renderer_class)
            rescue NameError => e
              Rails.logger.warn("[LcpRuby] Could not register renderer #{class_name}: #{e.message}")
            end
          end
        end

        def clear!
          @registry = {}
        end

        private

        def registry
          @registry ||= {}
        end
      end
    end
  end
end
