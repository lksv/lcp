module LcpRuby
  module Groups
    class ModelLoader
      include Contract

      # Returns all active group names from the DB.
      # @return [Array<String>]
      def all_group_names
        config = LcpRuby.configuration
        model_class = LcpRuby.registry.model_for(config.group_model)
        fields = config.group_model_fields.transform_keys(&:to_s)

        name_field = require_field!(fields, "name", "group_model_fields")
        active_field = fields["active"]

        scope = model_class.all
        if active_field && model_class.column_names.include?(active_field.to_s)
          scope = scope.where(active_field => true)
        end

        scope.pluck(name_field).map(&:to_s).sort
      rescue LcpRuby::Error, ActiveRecord::StatementInvalid => e
        log_warn("Failed to load group names: #{e.message}")
        []
      end

      # Returns group names the user belongs to via the membership table.
      # @param user [Object]
      # @return [Array<String>]
      def groups_for_user(user)
        return [] unless user

        config = LcpRuby.configuration
        group_class = LcpRuby.registry.model_for(config.group_model)
        membership_class = LcpRuby.registry.model_for(config.group_membership_model)

        group_fields = config.group_model_fields.transform_keys(&:to_s)
        membership_fields = config.group_membership_fields.transform_keys(&:to_s)

        name_field = require_field!(group_fields, "name", "group_model_fields")
        active_field = group_fields["active"]
        group_fk = require_field!(membership_fields, "group", "group_membership_fields")
        user_fk = require_field!(membership_fields, "user", "group_membership_fields")

        conn = group_class.connection
        qgfk = conn.quote_column_name(group_fk)
        gpk = conn.quote_column_name(group_class.primary_key)

        scope = group_class
          .joins("INNER JOIN #{membership_class.table_name} ON #{membership_class.table_name}.#{qgfk} = #{group_class.table_name}.#{gpk}")
          .where(membership_class.table_name => { user_fk => user.id })

        if active_field && group_class.column_names.include?(active_field.to_s)
          scope = scope.where(active_field => true)
        end

        scope.pluck(name_field).map(&:to_s)
      rescue LcpRuby::Error, ActiveRecord::StatementInvalid => e
        log_warn("Failed to load groups for user ##{user&.id}: #{e.message}")
        []
      end

      # Returns role names mapped to the given group via the mapping table.
      # Returns [] when group_role_mapping_model is nil (membership-only mode).
      # @param group_name [String]
      # @return [Array<String>]
      def roles_for_group(group_name)
        config = LcpRuby.configuration
        return [] unless config.group_role_mapping_model

        group_class = LcpRuby.registry.model_for(config.group_model)
        mapping_class = LcpRuby.registry.model_for(config.group_role_mapping_model)

        group_fields = config.group_model_fields.transform_keys(&:to_s)
        mapping_fields = config.group_role_mapping_fields.transform_keys(&:to_s)

        name_field = require_field!(group_fields, "name", "group_model_fields")
        mapping_group_fk = require_field!(mapping_fields, "group", "group_role_mapping_fields")
        role_field = require_field!(mapping_fields, "role", "group_role_mapping_fields")

        group_record = group_class.find_by(name_field => group_name)
        return [] unless group_record

        mapping_class.where(mapping_group_fk => group_record.id).pluck(role_field).map(&:to_s)
      rescue LcpRuby::Error, ActiveRecord::StatementInvalid => e
        log_warn("Failed to load roles for group '#{group_name}': #{e.message}")
        []
      end

      # Optimized: returns all roles derived from a user's group memberships
      # via a single query joining groups, memberships, and mappings.
      # @param user [Object]
      # @return [Array<String>]
      def roles_for_user(user)
        config = LcpRuby.configuration
        return [] unless user
        return [] unless config.group_role_mapping_model

        group_class = LcpRuby.registry.model_for(config.group_model)
        membership_class = LcpRuby.registry.model_for(config.group_membership_model)
        mapping_class = LcpRuby.registry.model_for(config.group_role_mapping_model)

        group_fields = config.group_model_fields.transform_keys(&:to_s)
        membership_fields = config.group_membership_fields.transform_keys(&:to_s)
        mapping_fields = config.group_role_mapping_fields.transform_keys(&:to_s)

        active_field = group_fields["active"]
        membership_group_fk = require_field!(membership_fields, "group", "group_membership_fields")
        user_fk = require_field!(membership_fields, "user", "group_membership_fields")
        mapping_group_fk = require_field!(mapping_fields, "group", "group_role_mapping_fields")
        role_field = require_field!(mapping_fields, "role", "group_role_mapping_fields")

        gt = group_class.table_name
        mt = membership_class.table_name
        mpt = mapping_class.table_name
        conn = mapping_class.connection
        gpk = conn.quote_column_name(group_class.primary_key)
        qmgfk = conn.quote_column_name(mapping_group_fk)
        qmbgfk = conn.quote_column_name(membership_group_fk)

        scope = mapping_class
          .joins("INNER JOIN #{gt} ON #{gt}.#{gpk} = #{mpt}.#{qmgfk}")
          .joins("INNER JOIN #{mt} ON #{mt}.#{qmbgfk} = #{gt}.#{gpk}")
          .where(mt => { user_fk => user.id })

        if active_field && group_class.column_names.include?(active_field.to_s)
          scope = scope.where(gt => { active_field => true })
        end

        scope.distinct.pluck(role_field).map(&:to_s)
      rescue LcpRuby::Error, ActiveRecord::StatementInvalid => e
        log_warn("Failed to load roles for user ##{user&.id}: #{e.message}")
        []
      end

      private

      # Extracts a required field mapping value, raising if missing.
      # Uses ArgumentError (not LcpRuby::Error) so configuration errors
      # propagate instead of being swallowed by error recovery.
      # @param fields [Hash] the field mapping hash
      # @param key [String] the key to look up
      # @param config_name [String] config attribute name for the error message
      # @return [String] the field name
      def require_field!(fields, key, config_name)
        value = fields[key]
        unless value
          raise ArgumentError,
            "Missing '#{key}' in #{config_name} configuration. " \
            "Check your LcpRuby.configure block."
        end
        value
      end

      def log_warn(message)
        if defined?(Rails) && Rails.respond_to?(:logger)
          Rails.logger.warn("[LcpRuby::Groups] #{message}")
        end
      end
    end
  end
end
