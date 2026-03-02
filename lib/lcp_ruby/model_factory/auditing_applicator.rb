module LcpRuby
  module ModelFactory
    class AuditingApplicator
      def initialize(model_class, model_definition)
        @model_class = model_class
        @model_definition = model_definition
      end

      def apply!
        return unless @model_definition.auditing?

        model_def = @model_definition
        options = model_def.auditing_options

        # Install after_create callback
        @model_class.after_create do
          next unless Auditing::Registry.available?

          Auditing::AuditWriter.log(
            action: :create,
            record: self,
            options: options,
            model_definition: model_def
          )
        end

        # Install after_update callback (skip if record was just created)
        @model_class.after_update do
          next unless Auditing::Registry.available?

          Auditing::AuditWriter.log(
            action: :update,
            record: self,
            options: options,
            model_definition: model_def
          )
        end

        # Install after_destroy callback
        @model_class.after_destroy do
          next unless Auditing::Registry.available?

          Auditing::AuditWriter.log(
            action: :destroy,
            record: self,
            options: options,
            model_definition: model_def
          )
        end

        # Add has_many :audit_logs association (polymorphic via auditable_type/auditable_id)
        fields = LcpRuby.configuration.audit_model_fields.transform_keys(&:to_s)
        type_field = fields["auditable_type"]
        id_field = fields["auditable_id"]

        @model_class.define_method(:audit_logs) do
          audit_class = Auditing::Registry.audit_model_class
          return audit_class.none unless audit_class

          audit_class
            .where(type_field => model_def.name, id_field => id)
            .order(created_at: :desc)
        end

        # Convenience method with limit
        @model_class.define_method(:audit_history) do |limit: 50|
          audit_logs.limit(limit)
        end
      end
    end
  end
end
