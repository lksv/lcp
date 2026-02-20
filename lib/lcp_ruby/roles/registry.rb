require "monitor"

module LcpRuby
  module Roles
    class Registry
      class << self
        # Returns all active role names from the DB-backed role model.
        # Results are cached until reload! is called.
        # @return [Array<String>] sorted array of role name strings
        def all_role_names
          return [] unless available?

          monitor.synchronize do
            @cache ||= load_role_names
          end
        end

        # Checks whether a role name exists in the registry.
        # @param name [String] role name to check
        # @return [Boolean]
        def valid_role?(name)
          all_role_names.include?(name.to_s)
        end

        # Clears the cached role names, forcing a reload on next access.
        def reload!
          monitor.synchronize do
            @cache = nil
          end
        end

        # Full reset — called from LcpRuby.reset!
        def clear!
          monitor.synchronize do
            @available = false
            @cache = nil
          end
        end

        # Whether the role model table is ready to query.
        def available?
          @available == true
        end

        # Mark registry as available (called after contract validation passes).
        def mark_available!
          @available = true
        end

        private

        def monitor
          @monitor ||= Monitor.new
        end

        def load_role_names
          config = LcpRuby.configuration
          model_class = LcpRuby.registry.model_for(config.role_model)
          fields = config.role_model_fields.transform_keys(&:to_s)

          name_field = fields["name"]
          active_field = fields["active"]

          scope = model_class.all

          # Filter by active field if the model has it
          if active_field && model_class.column_names.include?(active_field.to_s)
            scope = scope.where(active_field => true)
          end

          scope.pluck(name_field).map(&:to_s).sort
        rescue LcpRuby::Error, ActiveRecord::StatementInvalid => e
          if defined?(Rails) && Rails.respond_to?(:logger)
            Rails.logger.warn("[LcpRuby::Roles] Failed to load role names: #{e.message}")
          end
          []
        end
      end
    end
  end
end
