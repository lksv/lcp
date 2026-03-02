module LcpRuby
  module ModelFactory
    class SoftDeleteApplicator
      DISCARDED_BY_TYPE_COL = "discarded_by_type"
      DISCARDED_BY_ID_COL = "discarded_by_id"

      def initialize(model_class, model_definition)
        @model_class = model_class
        @model_definition = model_definition
      end

      def apply!
        return unless @model_definition.soft_delete?

        column = @model_definition.soft_delete_column
        apply_scopes(column)
        apply_instance_methods(column)
      end

      private

      def apply_scopes(column)
        col = column

        @model_class.scope :kept, -> { where(col => nil) }
        @model_class.scope :discarded, -> { where.not(col => nil) }
        @model_class.scope :with_discarded, -> { all }
      end

      def apply_instance_methods(column)
        col = column
        model_def = @model_definition
        by_type_col = DISCARDED_BY_TYPE_COL
        by_id_col = DISCARDED_BY_ID_COL

        # Precompute the list of cascade-eligible associations
        discard_associations = model_def.associations.select do |assoc|
          assoc.type == "has_many" && assoc.dependent == :discard && assoc.lcp_model?
        end.map do |assoc|
          fk = assoc.foreign_key || "#{model_def.name.singularize}_id"
          { target_model: assoc.target_model, foreign_key: fk }
        end.freeze

        @model_class.define_method(:discarded?) do
          self[col].present?
        end

        @model_class.define_method(:kept?) do
          self[col].nil?
        end

        @model_class.define_method(:cascade_discarded?) do
          self[by_type_col].present? && self[by_id_col].present?
        end

        @model_class.define_method(:discard!) do |by: nil|
          raise LcpRuby::Error, "Record is already discarded" if discarded?

          attrs = { col => Time.current }

          if by.present?
            attrs[by_type_col] = by.class.name
            attrs[by_id_col] = by.id
          end

          update_columns(attrs)

          # Audit the discard action
          if model_def.auditing? && Auditing::Registry.available?
            Auditing::AuditWriter.log(
              action: :discard,
              record: self,
              options: model_def.auditing_options,
              model_definition: model_def
            )
          end

          # Cascade discard to dependent: :discard children
          cascade_discard!(by: self)

          # Dispatch after_discard event
          Events::Dispatcher.dispatch(event_name: "after_discard", record: self)
        end

        @model_class.define_method(:undiscard!) do
          raise LcpRuby::Error, "Record is not discarded" unless discarded?

          # Cascade undiscard to children that were cascade-discarded by this record
          cascade_undiscard!

          update_columns(col => nil, by_type_col => nil, by_id_col => nil)

          # Audit the undiscard action
          if model_def.auditing? && Auditing::Registry.available?
            Auditing::AuditWriter.log(
              action: :undiscard,
              record: self,
              options: model_def.auditing_options,
              model_definition: model_def
            )
          end

          # Dispatch after_undiscard event
          Events::Dispatcher.dispatch(event_name: "after_undiscard", record: self)
        end

        @model_class.define_method(:cascade_discard!) do |by:|
          discard_associations.each do |assoc_info|
            child_class = LcpRuby.registry.model_for(assoc_info[:target_model])
            next unless child_class

            child_col = child_class.lcp_soft_delete_column
            child_class.where(assoc_info[:foreign_key] => id, child_col => nil).find_each do |child|
              child.discard!(by: by)
            end
          end
        end
        @model_class.send(:private, :cascade_discard!)

        @model_class.define_method(:cascade_undiscard!) do
          discard_associations.each do |assoc_info|
            child_class = LcpRuby.registry.model_for(assoc_info[:target_model])
            next unless child_class

            child_class.where(
              assoc_info[:foreign_key] => id,
              by_type_col => self.class.name,
              by_id_col => self.id
            ).find_each do |child|
              child.undiscard!
            end
          end
        end
        @model_class.send(:private, :cascade_undiscard!)

        # Class-level accessor for the soft delete column name
        @model_class.define_singleton_method(:lcp_soft_delete_column) { col }
      end
    end
  end
end
