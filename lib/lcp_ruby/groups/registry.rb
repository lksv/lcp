require "monitor"

module LcpRuby
  module Groups
    class Registry
      @monitor = Monitor.new

      class << self
        # Returns all group names from the configured loader.
        # Results are cached until reload! is called.
        # @return [Array<String>]
        def all_group_names
          return [] unless available?

          monitor.synchronize do
            @cache ||= loader.all_group_names
          end
        end

        # Returns group names the given user belongs to.
        # Not cached — user identity varies per request.
        # @param user [Object]
        # @return [Array<String>]
        def groups_for_user(user)
          return [] unless available?

          loader.groups_for_user(user)
        end

        # Returns role names mapped to the given group.
        # @param group_name [String]
        # @return [Array<String>]
        def roles_for_group(group_name)
          return [] unless available?

          loader.roles_for_group(group_name)
        end

        # Returns all roles derived from a user's group memberships.
        # Delegates to the loader (which may optimize with a single query).
        # @param user [Object]
        # @return [Array<String>]
        def roles_for_user(user)
          return [] unless available?

          loader.roles_for_user(user)
        end

        # Sets the loader that backs this registry.
        # @param loader_instance [Object] must include Groups::Contract
        def set_loader(loader_instance)
          monitor.synchronize do
            @loader = loader_instance
            @cache = nil
          end
        end

        # Clears the cached group names, forcing a reload on next access.
        def reload!
          monitor.synchronize do
            @cache = nil
          end
        end

        # Full reset — called from LcpRuby.reset!
        def clear!
          monitor.synchronize do
            @available = false
            @loader = nil
            @cache = nil
          end
        end

        # Whether the groups subsystem is configured and ready.
        def available?
          @available == true
        end

        # Mark registry as available (called after setup completes).
        def mark_available!
          @available = true
        end

        private

        def monitor
          @monitor
        end

        def loader
          @loader
        end
      end
    end
  end
end
