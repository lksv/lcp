module LcpRuby
  module Permissions
    class DefinitionValidator
      VALID_CRUD_ACTIONS = %w[index show create update destroy].freeze

      def self.install!(model_class)
        fields = LcpRuby.configuration.permission_model_fields.transform_keys(&:to_s)
        definition_field = fields["definition"]

        model_class.validate do |record|
          raw = record.public_send(definition_field)
          next if raw.blank?

          hash = raw.is_a?(String) ? JSON.parse(raw) : raw
          validator = DefinitionValidator.new(hash)
          validator.validate.each do |error|
            record.errors.add(definition_field, error)
          end
        rescue JSON::ParserError => e
          record.errors.add(definition_field, "contains invalid JSON: #{e.message}")
        end
      end

      def initialize(hash)
        @hash = hash
        @errors = []
      end

      def validate
        @errors = []

        validate_roles
        validate_default_role
        validate_field_overrides
        validate_record_rules

        @errors
      end

      private

      def validate_roles
        roles = @hash["roles"]
        unless roles.is_a?(Hash)
          @errors << "must have a 'roles' key that is a Hash"
          return
        end

        roles.each do |role_name, config|
          next unless config.is_a?(Hash)

          validate_role_crud(role_name, config)
          validate_role_fields(role_name, config)
        end
      end

      def validate_role_crud(role_name, config)
        crud = config["crud"]
        return unless crud

        unless crud.is_a?(Array)
          @errors << "role '#{role_name}': crud must be an Array"
          return
        end

        invalid = crud.map(&:to_s) - VALID_CRUD_ACTIONS
        if invalid.any?
          @errors << "role '#{role_name}': crud contains unknown actions: #{invalid.join(', ')}"
        end
      end

      def validate_role_fields(role_name, config)
        fields = config["fields"]
        return unless fields

        unless fields.is_a?(Hash)
          @errors << "role '#{role_name}': fields must be a Hash"
          return
        end

        %w[readable writable].each do |access|
          value = fields[access]
          next if value.nil? || value == "all"

          unless value.is_a?(Array)
            @errors << "role '#{role_name}': fields.#{access} must be 'all' or an Array"
          end
        end
      end

      def validate_default_role
        default_role = @hash["default_role"]
        return unless default_role

        unless default_role.is_a?(String)
          @errors << "default_role must be a String"
        end
      end

      def validate_field_overrides
        overrides = @hash["field_overrides"]
        return unless overrides

        unless overrides.is_a?(Hash)
          @errors << "field_overrides must be a Hash"
        end
      end

      def validate_record_rules
        rules = @hash["record_rules"]
        return unless rules

        unless rules.is_a?(Array)
          @errors << "record_rules must be an Array"
        end
      end
    end
  end
end
