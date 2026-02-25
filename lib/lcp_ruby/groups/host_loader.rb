module LcpRuby
  module Groups
    class HostLoader
      include Contract

      def initialize(adapter)
        @adapter = adapter
      end

      # Delegates to the host adapter.
      # @return [Array<String>]
      def all_group_names
        @adapter.all_group_names
      end

      # Delegates to the host adapter.
      # @param user [Object]
      # @return [Array<String>]
      def groups_for_user(user)
        @adapter.groups_for_user(user)
      end

      # Delegates to the host adapter.
      # @param group_name [String]
      # @return [Array<String>]
      def roles_for_group(group_name)
        @adapter.roles_for_group(group_name)
      end

      # Delegates to the host adapter when it provides an optimized implementation.
      # Otherwise falls back to the default composition.
      # @param user [Object]
      # @return [Array<String>]
      def roles_for_user(user)
        if @adapter.respond_to?(:roles_for_user)
          @adapter.roles_for_user(user)
        else
          super
        end
      end
    end
  end
end
