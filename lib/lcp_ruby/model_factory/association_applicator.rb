module LcpRuby
  module ModelFactory
    class AssociationApplicator
      def initialize(model_class, model_definition)
        @model_class = model_class
        @model_definition = model_definition
      end

      def apply!
        @model_definition.associations.each do |assoc|
          apply_association(assoc)
        end
      end

      private

      def apply_association(assoc)
        case assoc.type
        when "belongs_to"
          apply_belongs_to(assoc)
        when "has_many"
          apply_has_many(assoc)
        when "has_one"
          apply_has_one(assoc)
        end
      end

      def apply_belongs_to(assoc)
        opts = base_options(assoc)
        opts[:optional] = !assoc.required

        @model_class.belongs_to assoc.name.to_sym, **opts
      end

      def apply_has_many(assoc)
        opts = base_options(assoc)
        opts[:dependent] = assoc.dependent if assoc.dependent
        opts[:foreign_key] = assoc.foreign_key if assoc.foreign_key

        @model_class.has_many assoc.name.to_sym, **opts
      end

      def apply_has_one(assoc)
        opts = base_options(assoc)
        opts[:dependent] = assoc.dependent if assoc.dependent
        opts[:foreign_key] = assoc.foreign_key if assoc.foreign_key

        @model_class.has_one assoc.name.to_sym, **opts
      end

      def base_options(assoc)
        opts = {}
        if assoc.lcp_model?
          opts[:class_name] = assoc.resolved_class_name
        elsif assoc.class_name
          opts[:class_name] = assoc.class_name
        end
        opts[:foreign_key] = assoc.foreign_key if assoc.foreign_key && assoc.type == "belongs_to"
        opts
      end
    end
  end
end
