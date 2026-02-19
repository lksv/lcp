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
      LcpRuby.loader.navigable_view_groups.filter_map do |vg|
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
      end.sort_by { |entry| entry[:navigation].is_a?(Hash) ? (entry[:navigation]["position"] || 99) : 99 }
    end

    # --- Menu system helpers ---

    def menu_defined?
      LcpRuby.loader.menu_defined?
    end

    def menu_definition
      LcpRuby.loader.menu_definition
    end

    # Returns "top", "sidebar", or "both"
    def menu_layout
      return "top" unless menu_defined?

      menu_definition.layout_mode
    end

    # Filter menu items by visibility (role + presenter access)
    def visible_menu_items(items)
      return [] if items.nil?

      items.filter_map do |item|
        next unless menu_item_visible?(item)

        if item.group?
          visible_children = visible_menu_items(item.children)
          next if visible_children.empty?

          # Return a new item with filtered children
          Metadata::MenuItem.new(
            type: :group,
            label: item.label,
            icon: item.icon,
            children: visible_children,
            visible_when: item.visible_when,
            position: item.position,
            badge: item.badge
          )
        else
          item
        end
      end
    end

    # Check if a menu item should be visible to the current user
    def menu_item_visible?(item)
      return true if item.separator?

      # Role-based visibility
      if item.has_role_constraint?
        user = LcpRuby::Current.user
        return false unless user

        user_roles = Array(user.send(LcpRuby.configuration.role_method))
        return false unless item.visible_to_roles?(user_roles)
      end

      # View group items: check presenter accessibility
      if item.view_group?
        vg = LcpRuby.loader.view_group_definitions[item.view_group_name]
        return false unless vg

        presenter = LcpRuby.loader.presenter_definitions[vg.primary_presenter]
        return false unless presenter&.routable?
        return false unless presenter_accessible?(presenter)
      end

      true
    end

    # Check if a menu item is active for the current slug
    def menu_item_active?(item, current_slug)
      return false if current_slug.blank?

      item.contains_slug?(current_slug, LcpRuby.loader)
    end

    # Generate the path for a menu item
    def menu_item_path(item)
      if item.view_group?
        slug = item.resolved_slug(LcpRuby.loader)
        return nil unless slug

        lcp_ruby.resources_path(lcp_slug: slug)
      elsif item.link?
        item.url
      end
    end

    # Resolve display label for a menu item (using loader for view group resolution)
    def menu_item_label(item)
      item.resolved_label(LcpRuby.loader) || item.label
    end

    # Render badge HTML for a menu item, or nil if no badge / provider returns nil
    def menu_item_badge(item)
      return nil unless item.has_badge?

      provider = Services::Registry.lookup("data_providers", item.badge_provider)
      unless provider
        Rails.logger.debug("[LcpRuby::Menu] Data provider '#{item.badge_provider}' not registered")
        return nil
      end

      data = provider.call(user: LcpRuby::Current.user)
      return nil if data.nil?

      render_menu_badge(item, data)
    rescue => e
      raise unless Rails.env.production?
      Rails.logger.warn("[LcpRuby::Menu] Badge '#{item.badge_provider}' error: #{e.message}")
      nil
    end

    # Split items into main (non-bottom) and bottom items for sidebar
    def menu_main_items(items)
      items.reject(&:bottom?)
    end

    def menu_bottom_items(items)
      items.select(&:bottom?)
    end

    private

    def render_menu_badge(item, data)
      case item.badge_form
      when :renderer
        renderer = Display::RendererRegistry.renderer_for(item.badge_renderer)
        return nil unless renderer
        renderer.render(data, item.badge_options, view_context: self)
      when :template
        text = interpolate_badge_template(item.badge_template, data)
        return nil if text.blank?
        content_tag(:span, text, class: "lcp-menu-badge")
      when :partial
        render partial: item.badge_partial, locals: { data: data }
      end
    end

    def interpolate_badge_template(template, data)
      values = data.is_a?(Hash) ? data : { "value" => data }
      template.gsub(/\{([^}]+)\}/) { |_| values[$1.strip].to_s }
    end

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
