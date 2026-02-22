module LcpRuby
  module ModelFactory
    class PositioningApplicator
      def initialize(model_class, model_definition)
        @model_class = model_class
        @model_definition = model_definition
      end

      def apply!
        return unless @model_definition.positioned?

        col = @model_definition.positioning_field.to_sym
        scope_columns = @model_definition.positioning_scope.map(&:to_sym)

        if scope_columns.any?
          @model_class.positioned column: col, on: scope_columns
        else
          @model_class.positioned column: col
        end
      end
    end
  end
end
