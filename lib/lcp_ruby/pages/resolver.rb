module LcpRuby
  module Pages
    class Resolver
      class << self
        def find_by_slug(slug)
          pages_by_slug[slug] ||
            raise(MetadataError, "No page found with slug '#{slug}'")
        end

        def find_by_name(name)
          LcpRuby.loader.page_definition(name)
        end

        def routable_pages
          LcpRuby.loader.page_definitions.values.select(&:routable?)
        end

        def clear!
          @pages_by_slug = nil
        end

        private

        def pages_by_slug
          @pages_by_slug ||= LcpRuby.loader.page_definitions.values
            .select(&:routable?)
            .index_by(&:slug)
        end
      end
    end
  end
end
