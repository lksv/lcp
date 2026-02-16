module LcpRuby
  module Metadata
    class ModelDefinition
      attr_reader :name, :label, :label_plural, :table_name, :fields,
                  :validations, :associations, :scopes, :events, :options

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
          options: hash["options"] || {}
        )
      end

      def timestamps?
        options.fetch("timestamps", true)
      end

      def label_method
        options["label_method"] || "to_s"
      end

      def field(name)
        fields.find { |f| f.name == name.to_s }
      end

      def enum_fields
        fields.select(&:enum?)
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
    end
  end
end
