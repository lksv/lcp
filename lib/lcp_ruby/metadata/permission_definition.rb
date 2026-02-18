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

      # Merge configs from multiple roles using union/most-permissive semantics.
      # Returns a single virtual config hash.
      def merged_role_config_for(role_names)
        configs = role_names.map { |r| role_config_for(r) }
        configs = configs.reject(&:empty?)
        return roles[default_role.to_s] || {} if configs.empty?
        return configs.first if configs.size == 1

        merge_configs(configs)
      end

      def default?
        model == "_default"
      end

      private

      def merge_configs(configs)
        {
          "crud" => merge_crud(configs),
          "fields" => merge_fields(configs),
          "actions" => merge_actions(configs),
          "scope" => merge_scope(configs),
          "presenters" => merge_presenters(configs)
        }
      end

      # Union of all roles' CRUD lists
      def merge_crud(configs)
        configs.flat_map { |c| Array(c["crud"]) }.uniq
      end

      # Union of readable/writable fields; "all" wins
      def merge_fields(configs)
        {
          "readable" => merge_field_list(configs, "readable"),
          "writable" => merge_field_list(configs, "writable")
        }
      end

      def merge_field_list(configs, key)
        lists = configs.map { |c| c.dig("fields", key) }.compact
        return "all" if lists.any? { |l| l == "all" }
        lists.flat_map { |l| Array(l) }.uniq
      end

      # Union of allowed actions, intersection of denied
      def merge_actions(configs)
        return "all" if configs.any? { |c| c["actions"] == "all" }

        allowed = []
        denied_sets = []
        has_all_allowed = false

        configs.each do |c|
          acts = c["actions"]
          next unless acts.is_a?(Hash)

          if acts["allowed"] == "all"
            has_all_allowed = true
          else
            allowed.concat(Array(acts["allowed"]))
          end

          denied_sets << Array(acts["denied"]).map(&:to_s) if acts["denied"]
        end

        result = {}
        result["allowed"] = has_all_allowed ? "all" : allowed.uniq
        result["denied"] = denied_sets.empty? ? [] : denied_sets.reduce(:&)
        result
      end

      # If any role has "all", result is "all"; otherwise first non-nil scope wins.
      # Logs a warning when multiple roles define different scopes.
      def merge_scope(configs)
        return "all" if configs.any? { |c| c["scope"] == "all" }

        scopes = configs.map { |c| c["scope"] }.compact
        if scopes.size > 1
          Rails.logger.warn(
            "[LcpRuby::Permissions] Multiple scopes found for model '#{model}' " \
            "during multi-role merge. Using scope from first matching role; " \
            "other scopes are ignored: #{scopes.inspect}"
          )
        end

        scopes.first || "all"
      end

      # Union of presenter lists; "all" wins
      def merge_presenters(configs)
        lists = configs.map { |c| c["presenters"] }
        return "all" if lists.any? { |l| l == "all" }
        lists.flat_map { |l| Array(l) }.uniq
      end
    end
  end
end
