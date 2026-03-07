module LcpRuby
  module DataSource
    # Thread-safe registry for per-model data source adapter instances.
    module Registry
      class << self
        def available?
          @available == true
        end

        def mark_available!
          @available = true
        end

        def register(model_name, adapter)
          store[model_name.to_s] = adapter
        end

        def adapter_for(model_name)
          store[model_name.to_s]
        end

        def registered?(model_name)
          store.key?(model_name.to_s)
        end

        def clear!
          @available = false
          @store = nil
        end

        private

        def store
          @store ||= {}
        end
      end
    end
  end
end
