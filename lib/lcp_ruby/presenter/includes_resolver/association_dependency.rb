module LcpRuby
  module Presenter
    module IncludesResolver
      # Value object representing a single association that needs eager loading.
      #
      # @param path [Symbol, Hash] Association path in Rails includes format
      #   e.g. :company or { company: :industry }
      # @param reason [:display, :query]
      #   :display — need associated objects for rendering (to_label, association_list)
      #   :query   — need the table JOINed for WHERE/ORDER BY
      class AssociationDependency
        VALID_REASONS = %i[display query].freeze

        attr_reader :path, :reason

        def initialize(path:, reason:)
          @path = path
          @reason = reason.to_sym

          validate!
        end

        # Top-level association name regardless of nesting.
        # :company from either :company or { company: :industry }
        def association_name
          case path
          when Symbol then path
          when Hash   then path.keys.first
          else raise ArgumentError, "Invalid path type: #{path.class}"
          end
        end

        def nested?
          path.is_a?(Hash)
        end

        def query?
          reason == :query
        end

        def display?
          reason == :display
        end

        private

        def validate!
          unless path.is_a?(Symbol) || path.is_a?(Hash)
            raise ArgumentError, "path must be a Symbol or Hash, got #{path.class}"
          end

          unless VALID_REASONS.include?(reason)
            raise ArgumentError, "reason must be one of #{VALID_REASONS}, got #{reason.inspect}"
          end
        end
      end
    end
  end
end
