module LcpRuby
  module Presenter
    class ColumnSet
      include MetadataLookup

      attr_reader :presenter_definition, :permission_evaluator

      def initialize(presenter_definition, permission_evaluator)
        @presenter_definition = presenter_definition
        @permission_evaluator = permission_evaluator
      end

      def visible_table_columns
        all_columns = presenter_definition.table_columns
        readable = permission_evaluator.readable_fields

        all_columns.select do |col|
          field_visible?(col["field"], readable)
        end
      end

      def visible_form_fields(section_fields)
        writable = permission_evaluator.writable_fields

        section_fields.select do |field|
          writable.include?(field["field"])
        end
      end

      def visible_show_fields(section_fields)
        readable = permission_evaluator.readable_fields

        section_fields.select do |field|
          field_visible?(field["field"], readable)
        end
      end

      # Build a mapping from FK field name to the belongs_to AssociationDefinition,
      # filtered to only include FK fields the current user has permission to see.
      # Returns a Hash: { "company_id" => AssociationDefinition, ... }
      # Used by the index view to resolve associated objects instead of showing raw FK integers.
      def fk_association_map(model_definition)
        visible_fields = visible_table_columns.map { |c| c["field"] }
        model_definition.belongs_to_fk_map.select { |k, _| visible_fields.include?(k) }
      end

      private

      def field_visible?(field_path, readable)
        field_path = field_path.to_s

        if FieldValueResolver.template_field?(field_path)
          template_field_visible?(field_path, readable)
        elsif FieldValueResolver.dot_path?(field_path)
          dot_path_field_visible?(field_path)
        else
          readable.include?(field_path)
        end
      end

      def template_field_visible?(template, readable)
        refs = template.scan(/\{([^}]+)\}/).flatten.map(&:strip)
        refs.all? do |ref|
          if FieldValueResolver.dot_path?(ref)
            dot_path_field_visible?(ref)
          else
            readable.include?(ref)
          end
        end
      end

      def dot_path_field_visible?(field_path)
        parts = field_path.split(".")
        model_name = presenter_definition.model

        current_model_def = load_model_definition(model_name)
        return false unless current_model_def

        parts.each_with_index do |part, index|
          if index == parts.length - 1
            # Terminal field: check readability on current model
            evaluator = build_evaluator_for(current_model_def.name)
            return evaluator.field_readable?(part)
          else
            # Association segment: find and traverse
            assoc = current_model_def.associations.find { |a| a.name == part }
            return false unless assoc&.target_model

            current_model_def = load_model_definition(assoc.target_model)
            return false unless current_model_def
          end
        end

        false
      end

      def root_model_name
        presenter_definition.model
      end
    end
  end
end
