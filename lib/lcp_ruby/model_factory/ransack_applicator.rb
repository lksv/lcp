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
        model_def_name = @model_definition.name

        @model_class.define_singleton_method(:ransackable_attributes) do |auth_object = nil|
          if auth_object.is_a?(LcpRuby::Authorization::PermissionEvaluator)
            auth_object.readable_fields.map(&:to_s)
          else
            column_names
          end
        end
      end

      def define_ransackable_associations
        model_def_name = @model_definition.name

        @model_class.define_singleton_method(:ransackable_associations) do |auth_object = nil|
          model_def = LcpRuby.loader.model_definition(model_def_name)
          assoc_names = model_def.associations.select(&:lcp_model?).map(&:name).map(&:to_s)

          if auth_object.is_a?(LcpRuby::Authorization::PermissionEvaluator)
            assoc_names.select do |assoc_name|
              assoc_def = model_def.associations.find { |a| a.name == assoc_name }
              # has_many associations (no FK on this model) are always allowed
              next true unless assoc_def&.foreign_key
              auth_object.field_readable?(assoc_def.foreign_key)
            end
          else
            assoc_names
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
