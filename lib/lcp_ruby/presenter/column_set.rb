module LcpRuby
  module Presenter
    class ColumnSet
      attr_reader :presenter_definition, :permission_evaluator

      def initialize(presenter_definition, permission_evaluator)
        @presenter_definition = presenter_definition
        @permission_evaluator = permission_evaluator
      end

      def visible_table_columns
        all_columns = presenter_definition.table_columns
        readable = permission_evaluator.readable_fields

        all_columns.select do |col|
          readable.include?(col["field"])
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
          readable.include?(field["field"])
        end
      end
    end
  end
end
