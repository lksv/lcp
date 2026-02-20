module LcpRuby
  module Authorization
    class PermissionEvaluator
      attr_reader :permission_definition, :user, :model_name, :roles, :effective_config

      def initialize(permission_definition, user, model_name)
        @permission_definition = permission_definition
        @user = user
        @model_name = model_name
        @roles = resolve_roles(user)
        @effective_config = permission_definition.merged_role_config_for(@roles)
      end

      ACTION_ALIASES = {
        "edit" => "update",
        "new" => "create"
      }.freeze

      def can?(action)
        crud_list = effective_config["crud"]
        return false unless crud_list

        resolved = ACTION_ALIASES[action.to_s] || action.to_s
        crud_list.include?(resolved)
      end

      def can_for_record?(action, record)
        return false unless can?(action)

        # Check record-level rules
        permission_definition.record_rules.each do |rule|
          rule = rule.transform_keys(&:to_s) if rule.is_a?(Hash)
          next unless matches_condition?(record, rule["condition"])

          denied = (rule.dig("effect", "deny_crud") || []).map(&:to_s)
          except_roles = (rule.dig("effect", "except_roles") || []).map(&:to_s)

          if denied.include?(action.to_s) && (roles & except_roles).empty?
            return false
          end
        end

        true
      end

      def readable_fields
        field_list = effective_config.dig("fields", "readable")
        return [] unless field_list

        if field_list == "all"
          all_field_names
        else
          field_names = Array(field_list).map(&:to_s)
          apply_field_overrides_readable(field_names)
        end
      end

      def writable_fields
        field_list = effective_config.dig("fields", "writable")
        return [] unless field_list

        if field_list == "all"
          all_field_names
        else
          field_names = Array(field_list).map(&:to_s)
          apply_field_overrides_writable(field_names)
        end
      end

      def field_readable?(field_name)
        override = permission_definition.field_overrides[field_name.to_s]
        if override && override["readable_by"]
          return (roles & override["readable_by"].map(&:to_s)).any?
        end

        return true if readable_fields.include?(field_name.to_s)

        # Fallback: custom_data grants access to all custom fields
        custom_field_name?(field_name) && readable_fields.include?("custom_data")
      end

      def field_writable?(field_name)
        override = permission_definition.field_overrides[field_name.to_s]
        if override && override["writable_by"]
          return (roles & override["writable_by"].map(&:to_s)).any?
        end

        return true if writable_fields.include?(field_name.to_s)

        # Fallback: custom_data grants access to all custom fields
        custom_field_name?(field_name) && writable_fields.include?("custom_data")
      end

      def field_masked?(field_name)
        override = permission_definition.field_overrides[field_name.to_s]
        return false unless override && override["masked_for"]

        # Masked only if ALL roles are in masked_for
        masked_roles = override["masked_for"].map(&:to_s)
        roles.all? { |r| masked_roles.include?(r) }
      end

      def can_execute_action?(action_name)
        actions_config = effective_config["actions"]
        return true if actions_config == "all"
        return false unless actions_config.is_a?(Hash)

        denied = Array(actions_config["denied"]).map(&:to_s)
        return false if denied.include?(action_name.to_s)

        allowed = actions_config["allowed"]
        return true if allowed == "all"

        Array(allowed).map(&:to_s).include?(action_name.to_s)
      end

      def can_access_presenter?(presenter_name)
        presenters = effective_config["presenters"]
        return true if presenters == "all"

        Array(presenters).map(&:to_s).include?(presenter_name.to_s)
      end

      def apply_scope(base_relation)
        scope_config = effective_config["scope"]
        return base_relation if scope_config == "all" || scope_config.nil?

        ScopeBuilder.new(scope_config, user).apply(base_relation)
      end

      private

      def resolve_roles(user)
        return [ permission_definition.default_role ] unless user

        role_method = LcpRuby.configuration.role_method
        if user.respond_to?(role_method)
          raw = user.send(role_method)
          role_names = Array(raw).map(&:to_s)

          # When role_source is :model and registry is available, filter to valid DB roles
          if LcpRuby.configuration.role_source == :model && Roles::Registry.available?
            invalid = role_names.reject { |r| Roles::Registry.valid_role?(r) }
            if invalid.any? && defined?(Rails) && Rails.respond_to?(:logger)
              Rails.logger.warn("[LcpRuby::Roles] User ##{user.id} has unknown roles: #{invalid.join(', ')}")
            end
            role_names = role_names.select { |r| Roles::Registry.valid_role?(r) }
          end

          # Filter to roles that have configs; fall back to default if none match
          matching = role_names.select { |r| permission_definition.roles.key?(r) }
          matching.empty? ? [ permission_definition.default_role ] : matching
        else
          [ permission_definition.default_role ]
        end
      end

      # Returns all field names for this model, including belongs_to FK fields.
      # FK fields (e.g. company_id) are included because they are real DB columns that
      # need to be readable for index FK-column rendering and writable for association_select forms.
      # Note: this means `readable: all` / `writable: all` includes FK fields.
      def all_field_names
        model_def = LcpRuby.loader.model_definition(model_name)
        names = model_def.fields.map(&:name)
        names.concat(model_def.belongs_to_fk_map.keys)
        if model_def.custom_fields_enabled?
          names << "custom_data"
          cf_names = CustomFields::Registry.for_model(model_name)
            .select(&:active).map(&:field_name)
          names.concat(cf_names)
        end
        names.uniq
      rescue MetadataError
        []
      end

      def custom_field_name?(field_name)
        model_def = LcpRuby.loader.model_definition(model_name)
        return false unless model_def.custom_fields_enabled?

        CustomFields::Registry.for_model(model_name).any? { |d| d.field_name == field_name.to_s }
      rescue MetadataError
        false
      end

      def apply_field_overrides_readable(field_names)
        permission_definition.field_overrides.each do |field_name, override|
          if override["readable_by"]
            unless (roles & override["readable_by"].map(&:to_s)).any?
              field_names.delete(field_name.to_s)
            end
          end
        end
        field_names
      end

      def apply_field_overrides_writable(field_names)
        permission_definition.field_overrides.each do |field_name, override|
          if override["writable_by"]
            unless (roles & override["writable_by"].map(&:to_s)).any?
              field_names.delete(field_name.to_s)
            end
          end
        end
        field_names
      end

      def matches_condition?(record, condition)
        return true unless condition.is_a?(Hash)

        condition = condition.transform_keys(&:to_s)
        field = condition["field"]
        operator = condition["operator"]&.to_s
        value = condition["value"]

        return false unless field && record.respond_to?(field)

        actual = record.send(field)

        case operator
        when "eq" then actual.to_s == value.to_s
        when "not_eq", "neq" then actual.to_s != value.to_s
        when "in" then Array(value).map(&:to_s).include?(actual.to_s)
        when "not_in" then !Array(value).map(&:to_s).include?(actual.to_s)
        else actual.to_s == value.to_s
        end
      end
    end
  end
end
