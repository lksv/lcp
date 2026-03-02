module LcpRuby
  module ModelFactory
    class UserstampsApplicator
      def initialize(model_class, model_definition)
        @model_class = model_class
        @model_definition = model_definition
      end

      def apply!
        return unless @model_definition.userstamps?

        apply_callback!
        apply_associations!
      end

      private

      def apply_callback!
        creator_field = @model_definition.userstamps_creator_field
        updater_field = @model_definition.userstamps_updater_field
        creator_name_field = @model_definition.userstamps_creator_name_field
        updater_name_field = @model_definition.userstamps_updater_name_field

        @model_class.before_save do |record|
          user = LcpRuby::Current.user

          if record.new_record?
            record[creator_field] = user&.id
            record[creator_name_field] = user&.name if creator_name_field
          end

          record[updater_field] = user&.id
          record[updater_name_field] = user&.name if updater_name_field
        end
      end

      def apply_associations!
        user_class_name = LcpRuby.configuration.user_class

        creator_field = @model_definition.userstamps_creator_field
        updater_field = @model_definition.userstamps_updater_field
        creator_assoc = creator_field.sub(/_id$/, "").to_sym
        updater_assoc = updater_field.sub(/_id$/, "").to_sym

        @model_class.belongs_to creator_assoc,
          class_name: user_class_name,
          foreign_key: creator_field,
          optional: true

        @model_class.belongs_to updater_assoc,
          class_name: user_class_name,
          foreign_key: updater_field,
          optional: true
      end
    end
  end
end
