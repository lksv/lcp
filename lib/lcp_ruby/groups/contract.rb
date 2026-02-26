module LcpRuby
  module Groups
    # Interface module that defines the contract for group loaders.
    # Included by YamlLoader, ModelLoader, and HostLoader.
    module Contract
      # Returns all known group names.
      # @return [Array<String>]
      def all_group_names
        raise NotImplementedError, "#{self.class}#all_group_names must be implemented"
      end

      # Returns group names the given user belongs to.
      # @param user [Object] the current user
      # @return [Array<String>]
      def groups_for_user(user)
        raise NotImplementedError, "#{self.class}#groups_for_user must be implemented"
      end

      # Returns role names mapped to the given group.
      # @param group_name [String]
      # @return [Array<String>]
      def roles_for_group(group_name)
        raise NotImplementedError, "#{self.class}#roles_for_group must be implemented"
      end

      # Returns all roles derived from a user's group memberships.
      # Default implementation composes groups_for_user + roles_for_group.
      # @param user [Object] the current user
      # @return [Array<String>]
      def roles_for_user(user)
        groups_for_user(user).flat_map { |g| roles_for_group(g) }.uniq
      end
    end
  end
end
