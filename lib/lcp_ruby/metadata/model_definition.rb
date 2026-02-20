module LcpRuby
  module Metadata
    class ModelDefinition
      attr_reader :name, :label, :label_plural, :table_name, :fields,
                  :validations, :associations, :scopes, :events, :options,
                  :display_templates, :raw_hash

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

      def field(name)
        fields.find { |f| f.name == name.to_s }
      end

      def enum_fields
        fields.select(&:enum?)
      end

      def display_template(name = "default")
        display_templates[name.to_s]
      end

      # Returns a Hash mapping FK field name to its belongs_to AssociationDefinition.
      # e.g. { "company_id" => <AssociationDefinition name="company"> }
      # Memoized since it's called from multiple places (ColumnSet, DependencyCollector, PermissionEvaluator).
      def belongs_to_fk_map
        @belongs_to_fk_map ||= associations
          .select { |a| a.type == "belongs_to" && a.foreign_key.present? }
          .each_with_object({}) { |a, h| h[a.foreign_key] = a }
      end

      private

      def validate!
        raise MetadataError, "Model name is required" if @name.blank?
        validate_field_names_unique!
      end

      def validate_field_names_unique!
        names = fields.map(&:name)
        duplicates = names.select { |n| names.count(n) > 1 }.uniq
        if duplicates.any?
          raise MetadataError, "Duplicate field names in model '#{@name}': #{duplicates.join(', ')}"
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

      def self.parse_display_templates(data)
        return {} unless data.is_a?(Hash)
        data.each_with_object({}) do |(name, hash), result|
          result[name.to_s] = DisplayTemplateDefinition.from_hash(name, hash)
        end
      end
    end
  end
end
