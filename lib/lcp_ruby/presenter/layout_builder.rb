module LcpRuby
  module Presenter
    class LayoutBuilder
      attr_reader :presenter_definition, :model_definition

      def initialize(presenter_definition, model_definition)
        @presenter_definition = presenter_definition
        @model_definition = model_definition
      end

      def form_sections
        config = presenter_definition.form_config
        sections = config["sections"] || []
        result = sections.map do |s|
          if s["type"] == "nested_fields"
            normalize_nested_section(s)
          else
            normalize_section(s)
          end
        end
        append_custom_field_sections(result, context: :form)
      end

      def form_layout
        presenter_definition.form_config["layout"] || "flat"
      end

      def show_sections
        config = presenter_definition.show_config
        layout = config["layout"] || []
        result = layout.map do |s|
          if s["type"] == "association_list"
            enrich_association_list_section(s)
          else
            normalize_section(s)
          end
        end
        append_custom_field_sections(result, context: :show)
      end

      private

      # Append custom field sections to form or show sections.
      # Groups custom fields by their section attribute and creates
      # synthetic section hashes with custom field configs.
      def append_custom_field_sections(sections, context:)
        return sections unless model_definition.custom_fields_enabled?

        definitions = CustomFields::Registry.for_model(model_definition.name)
        return sections if definitions.empty?

        # Filter by context visibility
        visible_defs = definitions.select do |defn|
          defn.active && (context == :form ? defn.show_in_form : defn.show_in_show)
        end
        return sections if visible_defs.empty?

        # Group by section attribute
        grouped = visible_defs.group_by { |defn| defn.section.presence || "Custom Fields" }

        grouped.each do |section_title, defs|
          fields = defs.map do |defn|
            cf_type = defn.custom_type.presence || "string"
            field_config = {
              "field" => defn.field_name,
              "label" => defn.label,
              "custom_field" => true,
              "custom_field_definition" => defn,
              "field_definition" => Metadata::FieldDefinition.new(
                name: defn.field_name,
                type: custom_type_to_base_type(cf_type),
                label: defn.label
              )
            }
            field_config["placeholder"] = defn.placeholder if defn.placeholder.present?
            field_config["input_type"] = defn.input_type if defn.input_type.present?
            field_config["renderer"] = defn.renderer if defn.renderer.present?
            field_config["options"] = parse_renderer_options(defn.renderer_options) if defn.renderer_options.present?
            field_config
          end

          sections << { "title" => section_title, "fields" => fields }
        end

        sections
      end

      # Map custom field types to base types supported by FieldDefinition.
      def custom_type_to_base_type(custom_type)
        case custom_type
        when "enum" then "string"
        else custom_type
        end
      end

      def parse_renderer_options(options)
        case options
        when Hash then options
        when String
          CustomFields::Utils.safe_parse_json(
            options, context: "#{model_definition.name} renderer_options"
          )
        else {}
        end
      end

      def enrich_association_list_section(section)
        assoc_name = section["association"]
        assoc = model_definition.associations.find { |a| a.name == assoc_name }
        return section unless assoc&.target_model

        target_def = LcpRuby.loader.model_definition(assoc.target_model)
        return section unless target_def

        section.merge(
          "association_definition" => assoc,
          "target_model_definition" => target_def
        )
      rescue LcpRuby::MetadataError
        section
      end

      def normalize_section(section)
        fields = (section["fields"] || []).map do |f|
          # Handle multi_select fields with has_many through associations
          if f["input_type"] == "multi_select" && f.dig("input_options", "association")
            assoc_name = f.dig("input_options", "association")
            through_assoc = model_definition.associations.find { |a| a.name == assoc_name && a.through? }
            if through_assoc
              f = f.merge(
                "field_definition" => Metadata::FieldDefinition.new(
                  name: f["field"], type: "integer", label: assoc_name.to_s.humanize
                ),
                "multi_select_association" => through_assoc
              )
              next f
            end
          end

          field_def = model_definition.field(f["field"])

          if field_def.nil?
            assoc = model_definition.associations.find { |a| a.foreign_key == f["field"].to_s }
            if assoc
              f = f.merge(
                "field_definition" => Metadata::FieldDefinition.new(
                  name: f["field"],
                  type: "integer",
                  label: assoc.name.to_s.humanize
                ),
                "association" => assoc
              )
            end
          else
            f = f.merge("field_definition" => field_def)
            # Computed fields are readonly in forms
            f = f.merge("readonly" => true) if field_def.computed?
          end

          f
        end

        section.merge("fields" => fields)
      end

      def normalize_nested_section(section)
        assoc_name = section["association"]
        assoc = model_definition.associations.find { |a| a.name == assoc_name }
        return section unless assoc&.target_model

        target_def = LcpRuby.loader.model_definition(assoc.target_model)
        return section unless target_def

        fields = (section["fields"] || []).map do |f|
          field_def = target_def.field(f["field"])
          if field_def
            f.merge("field_definition" => field_def)
          else
            # Try association FK field on target model
            target_assoc = target_def.associations.find { |a| a.foreign_key == f["field"].to_s }
            if target_assoc
              f.merge(
                "field_definition" => Metadata::FieldDefinition.new(
                  name: f["field"],
                  type: "integer",
                  label: target_assoc.name.to_s.humanize
                ),
                "association" => target_assoc
              )
            end
          end
        end.compact

        result = section.merge(
          "fields" => fields,
          "association_definition" => assoc,
          "target_model_definition" => target_def
        )

        if section["sortable"]
          result["sortable_field"] = section["sortable"].is_a?(String) ? section["sortable"] : "position"
        end

        result
      end
    end
  end
end
