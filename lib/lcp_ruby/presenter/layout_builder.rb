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
        sections.map { |s| normalize_section(s) }
      end

      def show_sections
        config = presenter_definition.show_config
        layout = config["layout"] || []
        layout.map { |s| normalize_section(s) }
      end

      private

      def normalize_section(section)
        section = section.transform_keys(&:to_s) if section.is_a?(Hash)

        fields = (section["fields"] || []).map do |f|
          f = f.transform_keys(&:to_s) if f.is_a?(Hash)
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
          end

          f
        end

        section.merge("fields" => fields)
      end
    end
  end
end
