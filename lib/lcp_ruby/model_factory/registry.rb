module LcpRuby
  module ModelFactory
    class Registry
      def initialize
        @models = {}
      end

      def register(name, model_class)
        @models[name.to_s] = model_class
      end

      def model_for(name)
        @models[name.to_s] || raise(Error, "Model '#{name}' not registered")
      end

      def registered?(name)
        @models.key?(name.to_s)
      end

      def all
        @models.dup
      end

      def names
        @models.keys
      end

      def clear!
        @models.clear
      end
    end
  end
end
