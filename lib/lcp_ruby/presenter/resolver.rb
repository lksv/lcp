module LcpRuby
  module Presenter
    class Resolver
      class << self
        def find_by_name(name)
          LcpRuby.loader.presenter_definition(name)
        end

        def find_by_slug(slug)
          LcpRuby.loader.presenter_definitions.values.find { |p| p.slug == slug } ||
            raise(MetadataError, "No presenter found with slug '#{slug}'")
        end

        def presenters_for_model(model_name)
          LcpRuby.loader.presenter_definitions.values.select { |p| p.model == model_name.to_s }
        end

        def routable_presenters
          LcpRuby.loader.presenter_definitions.values.select(&:routable?)
        end
      end
    end
  end
end
