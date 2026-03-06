module LcpRuby
  module Metadata
    class ModelDefinition
      attr_reader :name, :label, :label_plural, :table_name, :fields,
                  :validations, :associations, :scopes, :events, :options,
                  :display_templates, :virtual_columns, :indexes, :raw_hash, :data_source_config
      attr_accessor :positioning_config

      # Backward compatibility alias
      alias_method :aggregates, :virtual_columns

      def initialize(attrs = {})
        @name = attrs[:name].to_s
        @label = attrs[:label] || @name.humanize
        @label_plural = attrs[:label_plural] || @label.pluralize
        @table_name = attrs[:table_name] || @name.pluralize
        @fields = attrs[:fields] || []
        @validations = attrs[:validations] || []
        @associations = attrs[:associations] || []
        @scopes = attrs[:scopes] || []
        @events = attrs[:events] || []
        @options = attrs[:options] || {}
        @display_templates = attrs[:display_templates] || {}
        @virtual_columns = attrs[:virtual_columns] || attrs[:aggregates] || {}
        @indexes = attrs[:indexes] || []
        @positioning_config = attrs[:positioning_config]
        @data_source_config = attrs[:data_source_config]
        @raw_hash = attrs[:raw_hash]

        validate!
      end

      def self.from_hash(hash)
        new(
          name: hash["name"],
          label: hash["label"],
          label_plural: hash["label_plural"],
          table_name: hash["table_name"],
          fields: parse_fields(hash["fields"]),
          validations: parse_validations(hash["validations"]),
          associations: parse_associations(hash["associations"]),
          scopes: (hash["scopes"] || []).map { |s| HashUtils.stringify_deep(s) },
          events: parse_events(hash["events"]),
          options: hash["options"] || {},
          display_templates: parse_display_templates(hash["display_templates"]),
          virtual_columns: parse_virtual_columns(hash),
          indexes: parse_indexes(hash["indexes"]),
          positioning_config: normalize_positioning(hash["positioning"]),
          data_source_config: hash["data_source"],
          raw_hash: hash
        )
      end

      def timestamps?
        options.fetch("timestamps", true)
      end

      def label_method
        options["label_method"] || "to_s"
      end

      def custom_fields_enabled?
        options.fetch("custom_fields", false) == true
      end

      def virtual?
        table_name == "_virtual"
      end

      # Returns true if this model is backed by an external data source (REST API, host adapter).
      def api_model?
        @data_source_config.is_a?(Hash) && @data_source_config["type"].present?
      end

      # Returns the data source type as a symbol: :db, :rest_json, or :host.
      def data_source_type
        return :db unless api_model?

        case @data_source_config["type"]
        when "rest_json" then :rest_json
        when "host" then :host
        else :db
        end
      end

      # Returns supported filter operators for this model's data source.
      # Falls back to a standard set for DB models.
      def supported_filter_operators
        return nil unless api_model?

        @data_source_config["supported_operators"]
      end

      def soft_delete?
        boolean_or_hash_option("soft_delete").first
      end

      def soft_delete_options
        boolean_or_hash_option("soft_delete").last
      end

      def soft_delete_column
        soft_delete_options.fetch("column", "discarded_at")
      end

      def auditing?
        boolean_or_hash_option("auditing").first
      end

      def auditing_options
        boolean_or_hash_option("auditing").last
      end

      def userstamps?
        boolean_or_hash_option("userstamps").first
      end

      def userstamps_options
        boolean_or_hash_option("userstamps").last
      end

      def userstamps_creator_field
        userstamps_options.fetch("created_by", "created_by_id")
      end

      def userstamps_updater_field
        userstamps_options.fetch("updated_by", "updated_by_id")
      end

      def userstamps_store_name?
        userstamps_options.fetch("store_name", false) == true
      end

      def userstamps_creator_name_field
        return nil unless userstamps_store_name?
        userstamps_creator_field.sub(/_id$/, "_name")
      end

      def userstamps_updater_name_field
        return nil unless userstamps_store_name?
        userstamps_updater_field.sub(/_id$/, "_name")
      end

      def userstamp_column_names
        return [] unless userstamps?

        cols = [ userstamps_creator_field, userstamps_updater_field ]
        if userstamps_store_name?
          cols << userstamps_creator_name_field
          cols << userstamps_updater_name_field
        end
        cols
      end

      def tree?
        boolean_or_hash_option("tree").first
      end

      def tree_options
        @tree_options ||= boolean_or_hash_option("tree").last
      end

      def tree_parent_field
        tree_options.fetch("parent_field", "parent_id")
      end

      def tree_children_name
        tree_options.fetch("children_name", "children")
      end

      def tree_parent_name
        tree_options.fetch("parent_name", "parent")
      end

      def tree_dependent
        tree_options.fetch("dependent", "destroy")
      end

      def tree_max_depth
        tree_options.fetch("max_depth", 10)
      end

      def tree_ordered?
        tree_options.fetch("ordered", false) == true
      end

      def tree_position_field
        tree_options.fetch("position_field", "position")
      end

      def field(name)
        fields.find { |f| f.name == name.to_s }
      end

      def parameterized_scopes
        scopes.select { |s| s["type"] == "parameterized" }
      end

      def parameterized_scope(name)
        parameterized_scopes.find { |s| s["name"] == name.to_s }
      end

      def enum_fields
        fields.select(&:enum?)
      end

      def display_template(name = "default")
        display_templates[name.to_s]
      end

      def virtual_column(name)
        virtual_columns[name.to_s]
      end

      def virtual_column_names
        virtual_columns.keys
      end

      # Backward compatibility aliases
      alias_method :aggregate, :virtual_column
      alias_method :aggregate_names, :virtual_column_names

      def positioned?
        @positioning_config.present?
      end

      def positioning_field
        positioning_config&.fetch("field", "position") || "position"
      end

      def positioning_scope
        Array(positioning_config&.fetch("scope", nil)).compact
      end

      # Returns a Hash mapping FK field name to its belongs_to AssociationDefinition.
      # e.g. { "company_id" => <AssociationDefinition name="company"> }
      # Memoized since it's called from multiple places (ColumnSet, DependencyCollector, PermissionEvaluator).
      # Includes tree-generated parent association when tree? is enabled.
      def belongs_to_fk_map
        @belongs_to_fk_map ||= begin
          map = associations
            .select { |a| a.type == "belongs_to" && a.foreign_key.present? }
            .each_with_object({}) { |a, h| h[a.foreign_key] = a }

          # Add tree-generated parent association if not already present
          if tree? && !map.key?(tree_parent_field)
            map[tree_parent_field] = AssociationDefinition.new(
              type: "belongs_to",
              name: tree_parent_name,
              target_model: name,
              foreign_key: tree_parent_field,
              required: false
            )
          end

          map
        end
      end

      private

      def boolean_or_hash_option(key)
        value = options[key]
        case value
        when true then [ true, {} ]
        when Hash then [ true, value ]
        else [ false, {} ]
        end
      end

      def validate!
        raise MetadataError, "Model name is required" if @name.blank?
        validate_field_names_unique!
        validate_virtual_column_names_unique!
      end

      def validate_field_names_unique!
        names = fields.map(&:name)
        duplicates = names.select { |n| names.count(n) > 1 }.uniq
        if duplicates.any?
          raise MetadataError, "Duplicate field names in model '#{@name}': #{duplicates.join(', ')}"
        end
      end

      def validate_virtual_column_names_unique!
        field_names = fields.map(&:name)
        collisions = virtual_column_names & field_names
        if collisions.any?
          raise MetadataError, "Model '#{@name}': virtual column names collide with field names: #{collisions.join(', ')}"
        end
      end

      private_class_method def self.normalize_positioning(raw)
        case raw
        when true
          { "field" => "position" }
        when Hash
          result = {}
          result["field"] = (raw["field"] || "position").to_s
          result["scope"] = Array(raw["scope"]).map(&:to_s) if raw["scope"]
          result
        when nil, false
          nil
        end
      end

      def self.parse_fields(fields_data)
        return [] unless fields_data.is_a?(Array)
        fields_data.map { |f| FieldDefinition.from_hash(f) }
      end

      def self.parse_validations(validations_data)
        return [] unless validations_data.is_a?(Array)
        validations_data.map { |v| ValidationDefinition.new(v) }
      end

      def self.parse_associations(associations_data)
        return [] unless associations_data.is_a?(Array)
        associations_data.map { |a| AssociationDefinition.from_hash(a) }
      end

      def self.parse_events(events_data)
        return [] unless events_data.is_a?(Array)
        events_data.map { |e| EventDefinition.from_hash(e) }
      end

      # Parse both "aggregates" and "virtual_columns" keys, merge, and error on collision.
      def self.parse_virtual_columns(hash)
        agg_data = hash["aggregates"] || {}
        vc_data = hash["virtual_columns"] || {}

        if agg_data.is_a?(Hash) && vc_data.is_a?(Hash)
          collisions = agg_data.keys.map(&:to_s) & vc_data.keys.map(&:to_s)
          if collisions.any?
            raise MetadataError, "Model '#{hash['name']}': name collision between aggregates and virtual_columns: #{collisions.join(', ')}"
          end
        end

        merged = {}
        parse_vc_hash(agg_data, merged) if agg_data.is_a?(Hash)
        parse_vc_hash(vc_data, merged) if vc_data.is_a?(Hash)
        merged
      end

      def self.parse_vc_hash(data, result)
        data.each do |name, hash|
          result[name.to_s] = VirtualColumnDefinition.from_hash(name, hash)
        end
      end

      def self.parse_display_templates(data)
        return {} unless data.is_a?(Hash)
        data.each_with_object({}) do |(name, hash), result|
          result[name.to_s] = DisplayTemplateDefinition.from_hash(name, hash)
        end
      end

      def self.parse_indexes(data)
        return [] unless data.is_a?(Array)
        data.map { |idx| HashUtils.stringify_deep(idx) }
      end
    end
  end
end
