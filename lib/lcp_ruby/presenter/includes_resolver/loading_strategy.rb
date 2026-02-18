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
        attr_reader :includes, :eager_load, :joins

        def initialize(includes: [], eager_load: [], joins: [])
          @includes = includes
          @eager_load = eager_load
          @joins = joins
        end

        # Chains all loading instructions onto the given AR scope.
        def apply(scope)
          scope = scope.includes(*@includes) if @includes.any?
          scope = scope.eager_load(*@eager_load) if @eager_load.any?
          scope = scope.joins(*@joins) if @joins.any?
          scope
        end

        def empty?
          @includes.empty? && @eager_load.empty? && @joins.empty?
        end
      end
    end
  end
end
