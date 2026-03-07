module LcpRuby
  module Presenter
    module IncludesResolver
      # Holds the resolved eager loading instructions and applies them to an AR scope.
      #
      # Three separate lists mirror the three ActiveRecord eager loading methods:
      #   - includes:   separate query by default (AR may use LEFT JOIN when combined with where/references)
      #   - eager_load: always LEFT OUTER JOIN (needed for WHERE/ORDER on association columns)
      #   - joins:      INNER JOIN (used alongside includes for has_many query deps)
      class LoadingStrategy
        attr_reader :includes, :eager_load, :joins, :api_preloads

        def initialize(includes: [], eager_load: [], joins: [], api_preloads: [])
          @includes = includes
          @eager_load = eager_load
          @joins = joins
          @api_preloads = api_preloads
        end

        # Chains all loading instructions onto the given AR scope.
        # When virtual columns add custom .select() to the scope, switches
        # :display dependencies to .preload() to avoid breaking the custom SELECT.
        def apply(scope)
          has_custom_select = scope.respond_to?(:select_values) && scope.select_values.any?

          if @includes.any?
            if has_custom_select
              # .preload() always uses separate queries, unaffected by custom SELECT
              scope = scope.preload(*@includes)
            else
              scope = scope.includes(*@includes)
            end
          end

          if @eager_load.any?
            if has_custom_select
              # Merge eager_loaded table columns into existing SELECT so they
              # survive the custom .select() from virtual columns
              @eager_load.each do |assoc_name|
                assoc_name = assoc_name.to_s if assoc_name.is_a?(Symbol)
                next unless assoc_name.is_a?(String)
                reflection = scope.klass.reflect_on_association(assoc_name.to_sym)
                next unless reflection
                scope = scope.select("#{reflection.klass.table_name}.*")
              end
            end
            scope = scope.eager_load(*@eager_load)
          end

          scope = scope.joins(*@joins) if @joins.any?
          scope
        end

        # Batch-preloads API associations for materialized records.
        # Call after the AR scope has been loaded (e.g. after pagination).
        def apply_api_preloads(records)
          return if @api_preloads.empty? || records.blank?

          @api_preloads.each do |preload|
            DataSource::ApiPreloader.preload(records, preload[:name], preload[:association])
          end
        end

        def empty?
          @includes.empty? && @eager_load.empty? && @joins.empty? && @api_preloads.empty?
        end
      end
    end
  end
end
