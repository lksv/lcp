module LcpRuby
  module Dsl
    class ModelBuilder
      COLUMN_OPTION_KEYS = %i[limit precision scale null].freeze

      def initialize(name)
        @name = name.to_s
        @label = nil
        @label_plural = nil
        @table_name_value = nil
        @fields = []
        @model_validations = []
        @associations = []
        @scopes = []
        @events = []
        @options = {}
      end

      def label(value)
        @label = value
      end

      def label_plural(value)
        @label_plural = value
      end

      def table_name(value)
        @table_name_value = value
      end

      def timestamps(value)
        @options["timestamps"] = value
      end

      def label_method(value)
        @options["label_method"] = value.to_s
      end

      def field(name, type, **options, &block)
        field_hash = {
          "name" => name.to_s,
          "type" => type.to_s
        }

        field_hash["label"] = options[:label] if options.key?(:label)
        field_hash["default"] = options[:default] if options.key?(:default)

        # Extract column options from top-level kwargs
        column_opts = {}
        COLUMN_OPTION_KEYS.each do |key|
          column_opts[key.to_s] = options[key] if options.key?(key)
        end
        field_hash["column_options"] = column_opts unless column_opts.empty?

        # Handle enum values
        if options.key?(:values)
          field_hash["enum_values"] = normalize_enum_values(options[:values])
        end

        # Handle field-level validations via block
        if block
          field_builder = FieldBuilder.new
          field_builder.instance_eval(&block)
          field_hash["validations"] = field_builder.validations unless field_builder.validations.empty?
        end

        @fields << field_hash
      end

      # Style B: model-level validates :field_name, :type, **options
      def validates(field_name, type, **options)
        @model_validations << {
          field: field_name.to_s,
          type: type.to_s,
          options: options
        }
      end

      # Model-level validations not attached to a field
      def validates_model(type, **options)
        validation = { "type" => type.to_s }
        validator_class = options.delete(:validator_class)
        validation["validator_class"] = validator_class if validator_class
        validation["options"] = stringify_keys(options) unless options.empty?
        @model_validations << { model_level: true, hash: validation }
      end

      def belongs_to(name, **options)
        add_association("belongs_to", name, **options)
      end

      def has_many(name, **options) # rubocop:disable Naming/PredicateName
        add_association("has_many", name, **options)
      end

      def has_one(name, **options) # rubocop:disable Naming/PredicateName
        add_association("has_one", name, **options)
      end

      def scope(name, **options)
        scope_hash = { "name" => name.to_s }
        scope_hash["where"] = stringify_keys(options[:where]) if options.key?(:where)
        scope_hash["where_not"] = stringify_keys(options[:where_not]) if options.key?(:where_not)
        scope_hash["order"] = stringify_keys(options[:order]) if options.key?(:order)
        scope_hash["limit"] = options[:limit] if options.key?(:limit)
        @scopes << scope_hash
      end

      # Lifecycle events
      def after_create(name = nil)
        event_name = name&.to_s || "after_create"
        @events << { "name" => event_name }
      end

      def after_update(name = nil)
        event_name = name&.to_s || "after_update"
        @events << { "name" => event_name }
      end

      def before_destroy(name = nil)
        event_name = name&.to_s || "before_destroy"
        @events << { "name" => event_name }
      end

      def after_destroy(name = nil)
        event_name = name&.to_s || "after_destroy"
        @events << { "name" => event_name }
      end

      # Field change events
      def on_field_change(name, field:, condition: nil)
        event_hash = {
          "name" => name.to_s,
          "type" => "field_change",
          "field" => field.to_s
        }
        event_hash["condition"] = condition if condition
        @events << event_hash
      end

      def to_hash
        hash = { "name" => @name }
        hash["label"] = @label if @label
        hash["label_plural"] = @label_plural if @label_plural
        hash["table_name"] = @table_name_value if @table_name_value

        fields_with_model_validations = merge_model_validations
        hash["fields"] = fields_with_model_validations unless fields_with_model_validations.empty?

        model_level_vals = extract_model_level_validations
        hash["validations"] = model_level_vals unless model_level_vals.empty?

        hash["associations"] = @associations unless @associations.empty?
        hash["scopes"] = @scopes unless @scopes.empty?
        hash["events"] = @events unless @events.empty?
        hash["options"] = @options unless @options.empty?

        hash
      end

      def to_yaml
        { "model" => to_hash }.to_yaml
      end

      private

      def add_association(type, name, **options)
        assoc_hash = {
          "type" => type,
          "name" => name.to_s
        }

        if options.key?(:model)
          assoc_hash["target_model"] = options[:model].to_s
        end
        if options.key?(:class_name)
          assoc_hash["class_name"] = options[:class_name].to_s
        end

        if options.key?(:foreign_key)
          assoc_hash["foreign_key"] = options[:foreign_key].to_s
        end

        if options.key?(:dependent)
          assoc_hash["dependent"] = options[:dependent].to_s
        end
        if options.key?(:required)
          assoc_hash["required"] = options[:required]
        end

        @associations << assoc_hash
      end

      def normalize_enum_values(values)
        case values
        when Hash
          values.map { |k, v| { "value" => k.to_s, "label" => v.to_s } }
        when Array
          values.map do |v|
            { "value" => v.to_s, "label" => v.to_s.tr("_", " ").capitalize }
          end
        else
          raise MetadataError, "Invalid enum values format: expected Hash or Array"
        end
      end

      def merge_model_validations
        fields = @fields.map(&:dup)

        @model_validations.each do |mv|
          next if mv[:model_level]

          field_hash = fields.find { |f| f["name"] == mv[:field] }
          unless field_hash
            raise MetadataError,
              "validates :#{mv[:field]} references unknown field '#{mv[:field]}' in model '#{@name}'"
          end

          validation = { "type" => mv[:type] }
          validator_class = mv[:options].delete(:validator_class)
          validation["validator_class"] = validator_class if validator_class

          opts = mv[:options].dup
          validation["options"] = stringify_keys(opts) unless opts.empty?

          field_hash["validations"] ||= []
          field_hash["validations"] << validation
        end

        fields
      end

      def extract_model_level_validations
        @model_validations.select { |mv| mv[:model_level] }.map { |mv| mv[:hash] }
      end

      def stringify_keys(hash)
        return hash unless hash.is_a?(Hash)

        hash.transform_keys(&:to_s).transform_values do |v|
          case v
          when Hash then stringify_keys(v)
          when Symbol then v.to_s
          else v
          end
        end
      end
    end
  end
end
