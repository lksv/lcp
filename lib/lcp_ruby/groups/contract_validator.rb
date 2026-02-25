module LcpRuby
  module Groups
    class ContractValidator
      # Validates that the group model definition satisfies the contract.
      # @param model_def [Metadata::ModelDefinition]
      # @param field_mapping [Hash] e.g. { name: "name", active: "active" }
      # @return [Metadata::ContractResult]
      def self.validate_group(model_def, field_mapping = nil)
        field_mapping = (field_mapping || LcpRuby.configuration.group_model_fields).transform_keys(&:to_s)
        errors = []
        warnings = []

        # Validate name field
        name_field_name = field_mapping["name"]
        name_field = model_def.fields.find { |f| f.name == name_field_name.to_s }

        if name_field.nil?
          errors << "Group model '#{model_def.name}' must have a '#{name_field_name}' field (mapped as name)"
        else
          unless name_field.type == "string"
            errors << "Group model '#{model_def.name}': '#{name_field_name}' field must be type 'string' (got '#{name_field.type}')"
          end

          unless name_field.validations.any? { |v| v.type == "uniqueness" }
            warnings << "Group model '#{model_def.name}': '#{name_field_name}' field should have a uniqueness validation"
          end
        end

        # Validate active field (optional)
        active_field_name = field_mapping["active"]
        if active_field_name
          active_field = model_def.fields.find { |f| f.name == active_field_name.to_s }
          if active_field && active_field.type != "boolean"
            errors << "Group model '#{model_def.name}': '#{active_field_name}' field must be type 'boolean' (got '#{active_field.type}')"
          end
        end

        Metadata::ContractResult.new(errors: errors, warnings: warnings)
      end

      # Validates that the group membership model definition satisfies the contract.
      # @param model_def [Metadata::ModelDefinition]
      # @param field_mapping [Hash] e.g. { group: "group_id", user: "user_id" }
      # @return [Metadata::ContractResult]
      def self.validate_membership(model_def, field_mapping = nil)
        field_mapping = (field_mapping || LcpRuby.configuration.group_membership_fields).transform_keys(&:to_s)
        errors = []
        warnings = []

        group_fk = field_mapping["group"]
        user_fk = field_mapping["user"]

        # Group FK: require belongs_to association (plain field accepted with warning)
        group_assoc = model_def.associations.find { |a| a.type == "belongs_to" && a.foreign_key == group_fk }
        unless group_assoc
          group_field = model_def.fields.find { |f| f.name == group_fk.to_s }
          if group_field
            warnings << "Group membership model '#{model_def.name}': '#{group_fk}' is a plain field; " \
                        "a belongs_to association is recommended for proper AR relationship support"
          else
            errors << "Group membership model '#{model_def.name}' must have a '#{group_fk}' belongs_to association or field (mapped as group)"
          end
        end

        # User FK: field or association
        user_field = model_def.fields.find { |f| f.name == user_fk.to_s }
        user_assoc = model_def.associations.find { |a| a.type == "belongs_to" && a.foreign_key == user_fk }
        unless user_field || user_assoc
          errors << "Group membership model '#{model_def.name}' must have a '#{user_fk}' field or belongs_to association (mapped as user)"
        end

        Metadata::ContractResult.new(errors: errors, warnings: warnings)
      end

      # Validates that the group role mapping model definition satisfies the contract.
      # @param model_def [Metadata::ModelDefinition]
      # @param field_mapping [Hash] e.g. { group: "group_id", role: "role_name" }
      # @return [Metadata::ContractResult]
      def self.validate_role_mapping(model_def, field_mapping = nil)
        field_mapping = (field_mapping || LcpRuby.configuration.group_role_mapping_fields).transform_keys(&:to_s)
        errors = []
        warnings = []

        # Group FK: require belongs_to association (plain field accepted with warning)
        group_fk = field_mapping["group"]
        group_assoc = model_def.associations.find { |a| a.type == "belongs_to" && a.foreign_key == group_fk }
        unless group_assoc
          group_field = model_def.fields.find { |f| f.name == group_fk.to_s }
          if group_field
            warnings << "Group role mapping model '#{model_def.name}': '#{group_fk}' is a plain field; " \
                        "a belongs_to association is recommended for proper AR relationship support"
          else
            errors << "Group role mapping model '#{model_def.name}' must have a '#{group_fk}' belongs_to association or field (mapped as group)"
          end
        end

        # Role field
        role_field_name = field_mapping["role"]
        role_field = model_def.fields.find { |f| f.name == role_field_name.to_s }
        if role_field.nil?
          errors << "Group role mapping model '#{model_def.name}' must have a '#{role_field_name}' field (mapped as role)"
        elsif role_field.type != "string"
          errors << "Group role mapping model '#{model_def.name}': '#{role_field_name}' field must be type 'string' (got '#{role_field.type}')"
        end

        Metadata::ContractResult.new(errors: errors, warnings: warnings)
      end
    end
  end
end
