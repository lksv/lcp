module LcpRuby
  module Display
    module Renderers
      class InternalLink < BaseRenderer
        SAFE_HREF_PATTERN = %r{\A(/|https?://)}i

        def render(value, options = {}, record: nil, view_context: nil)
          return nil if value.blank?

          href = value.to_s
          return view_context.content_tag(:span, href, class: "lcp-internal-link") unless href.match?(SAFE_HREF_PATTERN)

          label = options["label"] || href
          view_context.content_tag(:a, label, href: href, class: "lcp-internal-link")
        end
      end
    end
  end
end
