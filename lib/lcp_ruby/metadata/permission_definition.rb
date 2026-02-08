module LcpRuby
  module Metadata
    class PermissionDefinition
      attr_reader :model, :roles, :default_role, :field_overrides, :record_rules

      def initialize(attrs = {})
        @model = attrs[:model].to_s
        @roles = attrs[:roles] || {}
        @default_role = attrs[:default_role] || "viewer"
        @field_overrides = attrs[:field_overrides] || {}
        @record_rules = attrs[:record_rules] || []
      end

      def self.from_hash(hash)
        new(
          model: hash["model"],
          roles: hash["roles"] || {},
          default_role: hash["default_role"],
          field_overrides: hash["field_overrides"] || {},
          record_rules: hash["record_rules"] || []
        )
      end

      def role_config_for(role_name)
        roles[role_name.to_s] || roles[default_role.to_s] || {}
      end

      def default?
        model == "_default"
      end
    end
  end
end
