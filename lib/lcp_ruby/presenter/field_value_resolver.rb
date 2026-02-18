module LcpRuby
  module Presenter
    class FieldValueResolver
      include MetadataLookup

      attr_reader :model_definition, :permission_evaluator

      def initialize(model_definition, permission_evaluator)
        @model_definition = model_definition
        @permission_evaluator = permission_evaluator
      end

      # Resolve a field value from a record using various path types.
      #
      # @param record [ActiveRecord::Base] the record to resolve from
      # @param field_path [String] field name, dot-path, or template
      # @param fk_map [Hash] FK field name => AssociationDefinition (for backward compat)
      # @return [Object, nil] resolved value
      def resolve(record, field_path, fk_map: {})
        field_path = field_path.to_s
        return nil if field_path.blank?

        if self.class.template_field?(field_path)
          resolve_template(record, field_path, fk_map: fk_map)
        elsif self.class.dot_path?(field_path)
          resolve_dot_path(record, field_path)
        elsif fk_map.key?(field_path)
          resolve_fk(record, fk_map[field_path])
        else
          resolve_simple(record, field_path)
        end
      end

      def self.dot_path?(field)
        field.to_s.include?(".") && !field.to_s.include?("{")
      end

      def self.template_field?(field)
        field.to_s.include?("{") && field.to_s.include?("}")
      end

      private

      def root_model_name
        model_definition.name
      end

      def resolve_template(record, template, fk_map: {})
        template.gsub(/\{([^}]+)\}/) do |_match|
          ref = Regexp.last_match(1).strip
          resolve_ref(record, ref, fk_map: fk_map).to_s
        end
      end

      def resolve_ref(record, ref, fk_map: {})
        if self.class.dot_path?(ref)
          resolve_dot_path(record, ref)
        elsif fk_map.key?(ref)
          resolve_fk(record, fk_map[ref])
        else
          resolve_simple(record, ref)
        end
      end

      def resolve_dot_path(record, field_path)
        parts = field_path.split(".")
        current_record = record
        current_model_def = model_definition

        parts.each_with_index do |part, index|
          last_segment = (index == parts.length - 1)

          if last_segment
            # Terminal field — check permission on current model and read value
            return read_terminal_value(current_record, part, current_model_def)
          else
            # Association traversal
            assoc = current_model_def.associations.find { |a| a.name == part }
            return nil unless assoc

            # Permission check: the association name must be traversable
            # (we check readability of the final field on the target model)
            next_model_def = load_model_definition(assoc.target_model)
            return nil unless next_model_def

            if assoc.type == "has_many"
              # For has_many, resolve the remaining path on each related record
              return resolve_has_many(current_record, part, parts[(index + 1)..], next_model_def)
            end

            # belongs_to / has_one — traverse
            current_record = current_record.respond_to?(part) ? current_record.public_send(part) : nil
            return nil if current_record.nil?
            current_model_def = next_model_def
          end
        end
      end

      def resolve_has_many(record, assoc_name, remaining_parts, target_model_def)
        return nil unless record.respond_to?(assoc_name)

        related = record.public_send(assoc_name)
        return [] unless related.respond_to?(:map)

        remaining_path = remaining_parts.join(".")

        related.map do |related_record|
          sub_resolver = self.class.new(target_model_def, build_evaluator_for(target_model_def.name))
          sub_resolver.resolve(related_record, remaining_path)
        end.compact
      end

      def read_terminal_value(record, field_name, current_model_def)
        return nil if record.nil?

        # Permission check on the target model
        evaluator = build_evaluator_for(current_model_def.name)
        return nil unless evaluator.field_readable?(field_name)

        record.respond_to?(field_name) ? record.public_send(field_name) : nil
      end

      def resolve_fk(record, assoc)
        return nil unless record.respond_to?(assoc.name)

        assoc_record = record.public_send(assoc.name)
        return nil if assoc_record.nil?

        assoc_record.respond_to?(:to_label) ? assoc_record.to_label : assoc_record.to_s
      end

      def resolve_simple(record, field_name)
        record.respond_to?(field_name) ? record.public_send(field_name) : nil
      end
    end
  end
end
