module LcpRuby
  module Routing
    class PresenterRoutes
      class << self
        def draw(router)
          presenters = LcpRuby.loader.presenter_definitions.values.select(&:routable?)

          presenters.each do |presenter|
            draw_presenter_routes(router, presenter)
          end
        end

        private

        def draw_presenter_routes(router, presenter)
          slug = presenter.slug
          presenter_name = presenter.name

          router.scope module: :lcp_ruby do
            defaults = { lcp_presenter: presenter_name }

            if presenter.read_only?
              router.resources slug, only: [:index, :show], controller: "resources", defaults: defaults
            else
              router.resources slug, controller: "resources", defaults: defaults do
                router.member do
                  router.post "actions/:action_name", to: "actions#execute_single", as: :single_action
                end
                router.collection do
                  router.post "actions/:action_name", to: "actions#execute_collection", as: :collection_action
                  router.post "batch_actions/:action_name", to: "actions#execute_batch", as: :batch_action
                end
              end
            end
          end
        end
      end
    end
  end
end
