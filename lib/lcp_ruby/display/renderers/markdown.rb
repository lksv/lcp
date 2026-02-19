require "commonmarker"

module LcpRuby
  module Display
    module Renderers
      class Markdown < BaseRenderer
        ALLOWED_TAGS = %w[
          p br strong em del s a ul ol li blockquote pre code h1 h2 h3 h4 h5 h6
          table thead tbody tfoot tr th td hr img input div span
        ].freeze

        ALLOWED_ATTRIBUTES = %w[href src alt title class type checked disabled].freeze

        def render(value, options = {}, record: nil, view_context: nil)
          return nil if value.blank?

          html = Commonmarker.to_html(value.to_s, options: {
            render: { unsafe: true },
            extension: { table: true, tasklist: true, strikethrough: true, autolink: true }
          })
          view_context.content_tag(:div,
            view_context.sanitize(html, tags: ALLOWED_TAGS, attributes: ALLOWED_ATTRIBUTES),
            class: "lcp-markdown")
        end
      end
    end
  end
end
