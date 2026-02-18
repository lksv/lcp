module LcpRuby
  module LayoutHelper
    def hidden_on_classes(config)
      return "" unless config.is_a?(Hash)
      classes = []
      hidden_on = config["hidden_on"]
      if hidden_on.is_a?(Array)
        hidden_on.each do |breakpoint|
          classes << "lcp-hidden-#{breakpoint}"
        end
      elsif hidden_on.is_a?(String)
        classes << "lcp-hidden-#{hidden_on}"
      end
      classes.join(" ")
    end

    def navigable_presenters
      LcpRuby.loader.view_group_definitions.values.filter_map do |vg|
        presenter = LcpRuby.loader.presenter_definitions[vg.primary_presenter]
        next unless presenter&.routable?

        {
          presenter: presenter,
          label: presenter.label,
          slug: presenter.slug,
          icon: presenter.icon,
          navigation: vg.navigation_config
        }
      end.sort_by { |entry| entry[:navigation]["position"] || 99 }
    end
  end
end
