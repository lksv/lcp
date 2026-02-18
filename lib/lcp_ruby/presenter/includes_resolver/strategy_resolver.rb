module LcpRuby
  module Presenter
    module IncludesResolver
      # Maps a collection of AssociationDependency objects into a LoadingStrategy.
      #
      # Strategy matrix:
      #                       display only          query (or both)
      # belongs_to/has_one    includes              eager_load
      # has_many              includes              joins + includes
      #
      # Rationale: eager_load on has_many causes cartesian products that break
      # Kaminari pagination. Using joins (for query) + includes (for preload)
      # avoids this.
      class StrategyResolver
        # @param dependencies [Array<AssociationDependency>]
        # @param model_def [ModelDefinition]
        # @return [LoadingStrategy]
        def self.resolve(dependencies, model_def)
          new(dependencies, model_def).resolve
        end

        def initialize(dependencies, model_def)
          @dependencies = dependencies
          @model_def = model_def
        end

        def resolve
          includes_list = []
          eager_load_list = []
          joins_list = []

          # Group dependencies by association name to determine combined reason
          grouped = @dependencies.group_by(&:association_name)

          grouped.each do |assoc_name, deps|
            assoc = @model_def.associations.find { |a| a.name == assoc_name.to_s }
            next unless assoc

            has_query = deps.any?(&:query?)
            assoc_type = assoc.type
            # Use the most nested path among the deps for this association
            path = select_path(deps)

            if has_query
              # Query reason: need JOIN for WHERE/ORDER
              if assoc_type == "has_many"
                # has_many + query: joins for query, includes for preload
                joins_list << path
                includes_list << path
              else
                # belongs_to/has_one + query: eager_load (LEFT JOIN)
                eager_load_list << path
              end
            else
              # Display only: includes (separate query or LEFT JOIN, AR decides)
              includes_list << path
            end
          end

          LoadingStrategy.new(
            includes: includes_list.uniq,
            eager_load: eager_load_list.uniq,
            joins: joins_list.uniq
          )
        end

        private

        # Merge all paths for the same association into a single path.
        # e.g. :company + { company: :industry } + { company: :address }
        #   => { company: [:industry, :address] }
        # If no nested paths exist, returns the simple symbol path.
        def select_path(deps)
          nested = deps.select(&:nested?)
          return deps.first.path unless nested.any?

          merged_children = nested.flat_map { |d| Array(d.path.values.first) }.uniq
          if merged_children.size == 1
            { deps.first.association_name => merged_children.first }
          else
            { deps.first.association_name => merged_children }
          end
        end
      end
    end
  end
end
