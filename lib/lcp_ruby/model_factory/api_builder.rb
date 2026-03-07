module LcpRuby
  module ModelFactory
    # Builds API-backed model classes using ActiveModel instead of ActiveRecord.
    # Only applies compatible steps from the standard Builder.
    class ApiBuilder
      # Mapping from YAML field types to ActiveModel attribute types
      TYPE_MAP = {
        "string"   => :string,
        "text"     => :string,
        "integer"  => :integer,
        "float"    => :float,
        "decimal"  => :decimal,
        "boolean"  => :boolean,
        "date"     => :date,
        "datetime" => :datetime,
        "enum"     => :string,
        "uuid"     => :string,
        "email"    => :string,
        "phone"    => :string,
        "url"      => :string,
        "color"    => :string,
        "json"     => :string,
        "array"    => :string
      }.freeze

      attr_reader :model_definition

      def initialize(model_definition)
        @model_definition = model_definition
      end

      def build
        model_class = create_model_class
        apply_attributes(model_class)
        apply_enums(model_class)
        apply_label_method(model_class)
        apply_model_extensions(model_class)
        model_class.lcp_model_definition = model_definition
        model_class
      rescue => e
        raise LcpRuby::MetadataError,
          "Failed to build API model '#{model_definition.name}': #{e.message}"
      end

      private

      def create_model_class
        klass = Class.new do
          include DataSource::ApiModelConcern
        end
        class_name = model_definition.name.camelize

        # Remove previous definition to avoid "already initialized constant" warnings
        LcpRuby::Dynamic.send(:remove_const, class_name) if LcpRuby::Dynamic.const_defined?(class_name, false)

        LcpRuby::Dynamic.const_set(class_name, klass)
        klass
      end

      def apply_attributes(model_class)
        model_definition.fields.each do |field|
          attr_type = TYPE_MAP[field.resolved_base_type] || :string
          model_class.attribute field.name.to_sym, attr_type
        end
      end

      def apply_enums(model_class)
        model_definition.enum_fields.each do |field|
          valid_values = field.enum_value_names
          model_class.validates field.name.to_sym, inclusion: { in: valid_values }, allow_nil: true
        end
      end

      def apply_label_method(model_class)
        label_attr = model_definition.label_method
        return if label_attr == "to_s"

        model_class.define_method(:to_label) do
          send(label_attr)
        end
      end

      def apply_model_extensions(model_class)
        extensions = LcpRuby.configuration.model_extensions[model_definition.name] || []
        extensions.each { |block| block.call(model_class) }
      end
    end
  end
end
