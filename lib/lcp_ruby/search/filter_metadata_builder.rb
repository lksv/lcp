module LcpRuby
  module Search
    class FilterMetadataBuilder
      EXCLUDED_FIELD_NAMES = %w[id created_at updated_at].freeze
      EXCLUDED_FIELD_TYPES = %w[attachment rich_text json].freeze

      attr_reader :presenter_definition, :model_definition, :evaluator

      def initialize(presenter_definition, model_definition, evaluator)
        @presenter_definition = presenter_definition
        @model_definition = model_definition
        @evaluator = evaluator
      end

      def build
        {
          fields: build_fields,
          operator_labels: build_operator_labels,
          no_value_operators: OperatorRegistry::NO_VALUE_OPERATORS.map(&:to_s),
          multi_value_operators: OperatorRegistry::MULTI_VALUE_OPERATORS.map(&:to_s),
          range_operators: OperatorRegistry::RANGE_OPERATORS.map(&:to_s),
          parameterized_operators: OperatorRegistry::PARAMETERIZED_OPERATORS.map(&:to_s),
          presets: advanced_filter_config["presets"] || [],
          config: {
            max_conditions: advanced_filter_config["max_conditions"] || 10,
            default_combinator: advanced_filter_config["default_combinator"] || "and",
            allow_or_groups: advanced_filter_config.fetch("allow_or_groups", true),
            query_language: advanced_filter_config.fetch("query_language", false)
          }
        }
      end

      private

      def advanced_filter_config
        @advanced_filter_config ||= presenter_definition.advanced_filter_config
      end

      def max_association_depth
        advanced_filter_config["max_association_depth"] || 1
      end

      def field_options
        advanced_filter_config["field_options"] || {}
      end

      def build_fields
        if filterable_fields_configured?
          build_explicit_fields
        else
          build_auto_detected_fields
        end
      end

      def filterable_fields_configured?
        config = advanced_filter_config["filterable_fields"]
        config.is_a?(Array) && config.any?
      end

      def build_explicit_fields
        fields = advanced_filter_config["filterable_fields"].filter_map do |field_path|
          if field_path.include?(".")
            build_association_field(field_path)
          else
            build_direct_field(field_path)
          end
        end

        # Custom fields (filterable + active + readable)
        fields.concat(build_custom_field_entries)

        fields
      end

      def build_auto_detected_fields
        fields = []

        # Direct fields (excluding system fields, attachments, computed)
        model_definition.fields.each do |field_def|
          next if EXCLUDED_FIELD_NAMES.include?(field_def.name)
          next if EXCLUDED_FIELD_TYPES.include?(field_def.resolved_base_type)
          next if field_def.computed?
          next unless evaluator.field_readable?(field_def.name)

          fields << field_descriptor(field_def.name, field_def, nil)
        end

        # Association fields (depth 1): belongs_to label_method
        model_definition.associations.each do |assoc|
          next unless assoc.belongs_to?
          next unless assoc.traversable?
          next unless evaluator.field_readable?(assoc.foreign_key)

          target_def = load_model_definition(assoc.target_model)
          next unless target_def

          label_field = target_def.label_method
          next if label_field == "to_s"

          target_field_def = target_def.field(label_field)
          next unless target_field_def

          dot_path = "#{assoc.name}.#{label_field}"
          fields << field_descriptor(dot_path, target_field_def, assoc.name.humanize)
        end

        # Custom fields (filterable + active + readable)
        fields.concat(build_custom_field_entries)

        fields
      end

      def build_direct_field(field_name)
        field_def = model_definition.field(field_name)
        return unless field_def
        return unless evaluator.field_readable?(field_name)

        field_descriptor(field_name, field_def, nil)
      end

      def build_association_field(dot_path)
        parts = dot_path.split(".")
        return if parts.length > max_association_depth + 1

        current_model_def = model_definition
        group_parts = []

        # Traverse association chain (all parts except the last are associations)
        parts[0..-2].each do |assoc_name|
          assoc = current_model_def.associations.find { |a| a.name == assoc_name }
          return unless assoc
          return unless assoc.traversable?

          # Check FK readability for belongs_to at each level
          if assoc.belongs_to? && current_model_def == model_definition
            return unless evaluator.field_readable?(assoc.foreign_key)
          end

          group_parts << assoc.name.humanize

          target_def = load_model_definition(assoc.target_model)
          return unless target_def
          current_model_def = target_def
        end

        # Last part is the field name
        target_field_name = parts.last
        target_field_def = current_model_def.field(target_field_name)
        return unless target_field_def

        field_descriptor(dot_path, target_field_def, group_parts.join(" > "))
      end

      def field_descriptor(name, field_def, group)
        base_type = field_def.resolved_base_type
        operators = resolve_operators(name, base_type)

        descriptor = {
          name: name,
          label: field_def.label,
          type: base_type,
          group: group,
          operators: operators.map(&:to_s)
        }

        if field_def.enum?
          descriptor[:enum_values] = format_enum_values(field_def.enum_values)
        end

        descriptor
      end

      def resolve_operators(field_name, base_type)
        # Check for field-specific operator overrides
        # Strip association prefix to match field_options keys
        simple_name = field_name.split(".").last
        override = field_options.dig(field_name, "operators") || field_options.dig(simple_name, "operators")

        if override
          override.map(&:to_sym)
        else
          OperatorRegistry.operators_for(base_type)
        end
      end

      def build_operator_labels
        OperatorRegistry::ALL_OPERATORS.each_with_object({}) do |op, hash|
          hash[op.to_s] = OperatorRegistry.label_for(op)
        end
      end

      def build_custom_field_entries
        return [] unless model_definition.custom_fields_enabled?
        return [] unless CustomFields::Registry.available?

        definitions = CustomFields::Registry.for_model(model_definition.name)
        custom_fields_group = I18n.t("lcp_ruby.advanced_filter.field_groups.custom_fields", default: "Custom Fields")

        definitions.filter_map do |defn|
          next unless defn.active
          next unless defn.respond_to?(:filterable) && defn.filterable
          next unless evaluator.field_readable?(defn.field_name)

          custom_field_descriptor(defn, custom_fields_group)
        end
      end

      def custom_field_descriptor(defn, group)
        base_type = defn.custom_type.to_s
        operator_type = OperatorRegistry::OPERATORS_BY_TYPE.key?(base_type.to_sym) ? base_type.to_sym : :string
        operators = OperatorRegistry.operators_for(operator_type)

        descriptor = {
          name: "cf[#{defn.field_name}]",
          label: defn.label,
          type: base_type,
          group: group,
          operators: operators.map(&:to_s),
          custom_field: true
        }

        if base_type == "enum" && defn.enum_values.present?
          descriptor[:enum_values] = format_enum_values(defn.enum_values)
        end

        descriptor
      end

      def format_enum_values(raw_values)
        Array(raw_values).map do |ev|
          if ev.is_a?(Hash)
            value = (ev["value"] || ev[:value]).to_s
            label = (ev["label"] || ev[:label] || value.humanize).to_s
            [ value, label ]
          else
            [ ev.to_s, ev.to_s.humanize ]
          end
        end
      end

      def load_model_definition(model_name)
        LcpRuby.loader.model_definition(model_name)
      rescue LcpRuby::MetadataError
        nil
      end
    end
  end
end
