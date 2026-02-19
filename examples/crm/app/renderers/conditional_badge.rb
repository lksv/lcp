module LcpRuby::HostRenderers
  class ConditionalBadge < LcpRuby::Display::BaseRenderer
    def render(value, options = {}, record: nil, view_context: nil)
      rules = options["rules"] || []
      rules.each do |rule|
        if rule.key?("default")
          sub_opts = rule.dig("default", "options") || {}
          renderer = rule.dig("default", "renderer") || "badge"
          return view_context.render_display_value(value, renderer, sub_opts) if view_context
          return value.to_s
        elsif matches?(value, rule["match"])
          sub_opts = rule["options"] || {}
          renderer = rule["renderer"] || "badge"
          return view_context.render_display_value(value, renderer, sub_opts) if view_context
          return value.to_s
        end
      end
      value.to_s
    end

    private

    def matches?(value, match)
      return false unless match.is_a?(Hash)

      if match.key?("eq")
        value.to_s == match["eq"].to_s
      elsif match.key?("in")
        Array(match["in"]).map(&:to_s).include?(value.to_s)
      elsif match.key?("not_eq")
        value.to_s != match["not_eq"].to_s
      elsif match.key?("not_in")
        !Array(match["not_in"]).map(&:to_s).include?(value.to_s)
      else
        false
      end
    end
  end
end
