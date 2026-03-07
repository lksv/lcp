module LcpRuby
  module ModelFactory
    # Backward compatibility — delegates to VirtualColumnApplicator
    class AggregateApplicator
      def initialize(model_class, model_definition)
        @delegate = VirtualColumnApplicator.new(model_class, model_definition)
      end

      def apply!
        @delegate.apply!
      end
    end
  end
end
