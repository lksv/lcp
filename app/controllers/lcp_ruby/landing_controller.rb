module LcpRuby
  class LandingController < ApplicationController
    skip_before_action :set_presenter_and_model
    skip_before_action :authorize_presenter_access

    def show
      slug = resolve_landing_slug
      if slug
        redirect_to lcp_ruby.resources_path(lcp_slug: slug)
      else
        raise LcpRuby::MetadataError, "No landing page configured and no routable pages found"
      end
    end

    private

    def resolve_landing_slug
      config = LcpRuby.configuration.landing_page

      if config.is_a?(Hash)
        user_roles = Array(current_user&.send(LcpRuby.configuration.role_method)).map(&:to_s)
        # Find first matching role
        user_roles.each do |role|
          return config[role] if config[role]
        end
        # Fall back to default
        return config["default"] if config["default"]
      elsif config.is_a?(String)
        return config
      end

      # Fallback: first routable page from navigable view groups
      first_navigable_slug
    end

    def first_navigable_slug
      LcpRuby.loader.navigable_view_groups.each do |vg|
        page_name = vg.primary_page
        page = LcpRuby.loader.page_definitions[page_name]
        return page.slug if page&.routable?
      end
      nil
    end
  end
end
