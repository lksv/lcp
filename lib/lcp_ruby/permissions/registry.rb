require "monitor"

module LcpRuby
  module Permissions
    class Registry
      class << self
        # Returns cached PermissionDefinition for a given model name, or nil.
        # @param model_name [String] the model name to query (or "_default")
        # @return [Metadata::PermissionDefinition, nil]
        def for_model(model_name)
          return nil unless available?

          key = model_name.to_s
          monitor.synchronize do
            @cache[key] = load_and_parse(key) unless @cache.key?(key)
            @cache[key]
          end
        end

        # Returns all active DB permission definitions (parsed).
        # Used by impersonation to collect role names.
        # @return [Array<Metadata::PermissionDefinition>]
        def all_definitions
          return [] unless available?

          monitor.synchronize do
            load_all_definitions
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

        # Full reset - called from LcpRuby.reset!
        def clear!
          monitor.synchronize do
            @available = false
            @cache = {}
          end
        end

        # Whether the permission_config table is ready to query.
        def available?
          @available == true
        end

        # Mark registry as available (called after contract validation passes).
        def mark_available!
          @available = true
          @cache ||= {}
        end

        private

        def monitor
          @monitor ||= Monitor.new
        end

        def load_and_parse(model_name)
          config = LcpRuby.configuration
          model_class = LcpRuby.registry.model_for(config.permission_model)
          fields = config.permission_model_fields.transform_keys(&:to_s)

          model_name_field = fields["target_model"]
          definition_field = fields["definition"]
          active_field = fields["active"]

          scope = model_class.where(model_name_field => model_name)
          scope = scope.where(active_field => true) if active_field && model_class.column_names.include?(active_field.to_s)

          record = scope.order(:id).last
          return nil unless record

          parse_definition(record, definition_field, model_name)
        rescue LcpRuby::Error, ActiveRecord::StatementInvalid => e
          log_warn("Failed to load permission definition for '#{model_name}': #{e.message}")
          nil
        end

        def load_all_definitions
          config = LcpRuby.configuration
          model_class = LcpRuby.registry.model_for(config.permission_model)
          fields = config.permission_model_fields.transform_keys(&:to_s)

          definition_field = fields["definition"]
          model_name_field = fields["target_model"]
          active_field = fields["active"]

          scope = model_class.all
          scope = scope.where(active_field => true) if active_field && model_class.column_names.include?(active_field.to_s)

          scope.map do |record|
            mn = record.public_send(model_name_field)
            parse_definition(record, definition_field, mn)
          end.compact
        rescue LcpRuby::Error, ActiveRecord::StatementInvalid => e
          log_warn("Failed to load all permission definitions: #{e.message}")
          []
        end

        def parse_definition(record, definition_field, model_name)
          raw = record.public_send(definition_field)
          return nil if raw.blank?

          hash = raw.is_a?(String) ? JSON.parse(raw) : raw
          hash["model"] = model_name
          Metadata::PermissionDefinition.from_hash(hash)
        rescue JSON::ParserError => e
          log_warn("Invalid JSON in permission definition for '#{model_name}': #{e.message}")
          nil
        end

        def log_warn(message)
          Rails.logger.warn("[LcpRuby::Permissions] #{message}") if defined?(Rails) && Rails.respond_to?(:logger)
        end
      end
    end
  end
end
