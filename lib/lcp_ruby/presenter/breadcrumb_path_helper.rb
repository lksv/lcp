module LcpRuby
  module Presenter
    class BreadcrumbPathHelper
      def initialize(engine_routes)
        @routes = engine_routes
      end

      def resources_path(slug)
        @routes.resources_path(lcp_slug: slug)
      end

      def resource_path(slug, id)
        @routes.resource_path(lcp_slug: slug, id: id)
      end
    end
  end
end
