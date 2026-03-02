module LcpRuby
  module ModelFactory
    class RansackApplicator
      def initialize(model_class, model_definition)
        @model_class = model_class
        @model_definition = model_definition
      end

      def apply!
        define_ransackable_attributes
        define_ransackable_associations
        define_ransackable_scopes
      end

      private

      def define_ransackable_attributes
        @model_class.define_singleton_method(:ransackable_attributes) do |auth_object = nil|
          if auth_object.is_a?(LcpRuby::Authorization::PermissionEvaluator)
            auth_object.readable_fields.map(&:to_s)
          else
            column_names
          end
        end
      end

      def define_ransackable_associations
        lcp_assocs = @model_definition.associations.select(&:lcp_model?).freeze
        all_assoc_names = lcp_assocs.map { |a| a.name.to_s }.freeze

        @model_class.define_singleton_method(:ransackable_associations) do |auth_object = nil|
          if auth_object.is_a?(LcpRuby::Authorization::PermissionEvaluator)
            lcp_assocs
              .select { |a| a.foreign_key.nil? || auth_object.field_readable?(a.foreign_key) }
              .map { |a| a.name.to_s }
          else
            all_assoc_names
          end
        end
      end

      def define_ransackable_scopes
        @model_class.define_singleton_method(:ransackable_scopes) do |_auth_object = nil|
          # Scope names are derived from model's scope definitions
          # Filter scopes exposed via presenter search_config are handled at query time
          []
        end
      end
    end
  end
end
