require "monitor"

module LcpRuby
  module CustomFields
    class Registry
      class << self
        # Returns custom field definitions for a given model name.
        # Results are cached per model_name.
        # @param model_name [String] the model name to query
        # @return [Array] array of definition records, ordered by position
        def for_model(model_name)
          return [] unless available?

          key = model_name.to_s
          monitor.synchronize do
            @cache[key] ||= load_definitions(key)
          end
        end

        # Clear cache for one model or all models.
        # @param model_name [String, nil] specific model to reload, or nil for all
        def reload!(model_name = nil)
          monitor.synchronize do
            if model_name
              @cache.delete(model_name.to_s)
            else
              @cache = {}
            end
          end
        end

        # Full reset — called from LcpRuby.reset!
        def clear!
          monitor.synchronize do
            @available = false
            @cache = {}
          end
        end

        # Whether the custom_field_definitions table is ready to query.
        def available?
          @available == true
        end

        # Mark registry as available (called after building the built-in model).
        def mark_available!
          @available = true
        end

        private

        def monitor
          @monitor ||= Monitor.new
        end

        def load_definitions(model_name)
          model_class = LcpRuby.registry.model_for("custom_field_definition")
          model_class
            .where(target_model: model_name, active: true)
            .order(:position, :id)
            .to_a
        rescue LcpRuby::Error, ActiveRecord::StatementInvalid => e
          Rails.logger.warn("[LcpRuby::CustomFields] Failed to load definitions for '#{model_name}': #{e.message}") if defined?(Rails) && Rails.respond_to?(:logger)
          []
        end
      end
    end
  end
end
