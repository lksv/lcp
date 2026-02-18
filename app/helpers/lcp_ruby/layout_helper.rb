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
        next unless presenter_accessible?(presenter)

        all_slugs = vg.presenter_names.filter_map do |name|
          LcpRuby.loader.presenter_definitions[name]&.slug
        end

        {
          presenter: presenter,
          label: presenter.label,
          slug: presenter.slug,
          icon: presenter.icon,
          navigation: vg.navigation_config,
          all_slugs: all_slugs
        }
      end.sort_by { |entry| entry[:navigation]["position"] || 99 }
    end

    private

    def presenter_accessible?(presenter)
      user = LcpRuby::Current.user
      return true unless user

      perm_def = LcpRuby.loader.permission_definition(presenter.model)
      evaluator = LcpRuby::Authorization::PermissionEvaluator.new(perm_def, user, presenter.model)
      evaluator.can_access_presenter?(presenter.name)
    rescue LcpRuby::MetadataError => e
      Rails.logger.debug("[LcpRuby::Menu] No permissions for model '#{presenter.model}', showing menu item: #{e.message}")
      true
    end
  end
end
