module LcpRuby::HostRenderers
  class StatusTimeline < LcpRuby::Display::BaseRenderer
    def render(value, options = {}, record: nil, view_context: nil)
      steps = options["steps"] || []
      return value.to_s if steps.empty?

      current_value = value.to_s
      current_index = steps.index(current_value)

      html_parts = steps.each_with_index.map do |step, index|
        step_label = step.to_s.tr("_", " ").capitalize

        if current_index.nil?
          css_class = "lcp-timeline-step lcp-timeline-step--future"
          icon = ""
        elsif index < current_index
          css_class = "lcp-timeline-step lcp-timeline-step--completed"
          icon = '<span class="lcp-timeline-icon">&#10003;</span>'
        elsif index == current_index
          css_class = "lcp-timeline-step lcp-timeline-step--current"
          icon = '<span class="lcp-timeline-icon">&#9679;</span>'
        else
          css_class = "lcp-timeline-step lcp-timeline-step--future"
          icon = '<span class="lcp-timeline-icon">&#9675;</span>'
        end

        connector = if index < steps.length - 1
          completed = current_index && index < current_index
          connector_class = completed ? "lcp-timeline-connector--completed" : ""
          "<span class=\"lcp-timeline-connector #{connector_class}\"></span>"
        else
          ""
        end

        "<span class=\"#{css_class}\">#{icon}<span class=\"lcp-timeline-label\">#{ERB::Util.html_escape(step_label)}</span></span>#{connector}"
      end

      style = <<~CSS.gsub(/\s+/, " ").strip
        <style>
          .lcp-timeline { display: flex; align-items: center; gap: 0; flex-wrap: wrap; }
          .lcp-timeline-step { display: inline-flex; align-items: center; gap: 4px; padding: 2px 6px; border-radius: 4px; font-size: 0.8em; white-space: nowrap; }
          .lcp-timeline-step--completed { color: #16a34a; }
          .lcp-timeline-step--completed .lcp-timeline-icon { color: #16a34a; font-weight: bold; }
          .lcp-timeline-step--current { color: #2563eb; font-weight: 600; background: #dbeafe; }
          .lcp-timeline-step--current .lcp-timeline-icon { color: #2563eb; }
          .lcp-timeline-step--future { color: #9ca3af; }
          .lcp-timeline-step--future .lcp-timeline-icon { color: #d1d5db; }
          .lcp-timeline-connector { display: inline-block; width: 16px; height: 2px; background: #d1d5db; vertical-align: middle; }
          .lcp-timeline-connector--completed { background: #16a34a; }
          .lcp-timeline-label { display: inline; }
        </style>
      CSS

      "#{style}<span class=\"lcp-timeline\">#{html_parts.join}</span>"
    end
  end
end
