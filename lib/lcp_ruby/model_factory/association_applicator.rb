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
          apply_nested_attributes(assoc)
        when "has_one"
          apply_has_one(assoc)
          apply_nested_attributes(assoc)
        end
      end

      def apply_belongs_to(assoc)
        opts = base_options(assoc)
        opts[:optional] = !assoc.required
        opts[:polymorphic] = true if assoc.polymorphic
        opts[:dependent] = assoc.dependent if assoc.dependent
        opts[:counter_cache] = assoc.counter_cache unless assoc.counter_cache.nil?
        opts[:touch] = assoc.touch unless assoc.touch.nil?
        apply_common_options(opts, assoc)

        @model_class.belongs_to assoc.name.to_sym, **opts
      end

      def apply_has_many(assoc)
        opts = base_options(assoc)
        opts[:as] = assoc.as.to_sym if assoc.as.present?

        if assoc.through?
          opts[:through] = assoc.through.to_sym
          opts[:source] = assoc.source.to_sym if assoc.source.present?
        else
          opts[:dependent] = assoc.dependent if assoc.dependent
          opts[:foreign_key] = assoc.foreign_key if assoc.foreign_key
        end

        apply_common_options(opts, assoc)

        @model_class.has_many assoc.name.to_sym, **opts
      end

      def apply_has_one(assoc)
        opts = base_options(assoc)
        opts[:as] = assoc.as.to_sym if assoc.as.present?

        if assoc.through?
          opts[:through] = assoc.through.to_sym
          opts[:source] = assoc.source.to_sym if assoc.source.present?
        else
          opts[:dependent] = assoc.dependent if assoc.dependent
          opts[:foreign_key] = assoc.foreign_key if assoc.foreign_key
        end

        apply_common_options(opts, assoc)

        @model_class.has_one assoc.name.to_sym, **opts
      end

      def apply_nested_attributes(assoc)
        return unless assoc.nested_attributes

        opts = {}
        na = assoc.nested_attributes

        opts[:allow_destroy] = na["allow_destroy"] if na.key?("allow_destroy")
        opts[:limit] = na["limit"] if na.key?("limit")
        opts[:update_only] = na["update_only"] if na.key?("update_only")

        if na["reject_if"]
          reject_value = na["reject_if"]
          opts[:reject_if] = case reject_value.to_s
          when "all_blank" then :all_blank
          else
            reject_value.is_a?(Symbol) ? reject_value : reject_value.to_s.to_sym
          end
        end

        @model_class.accepts_nested_attributes_for(assoc.name.to_sym, **opts)
      end

      def base_options(assoc)
        opts = {}
        # Skip class_name for polymorphic belongs_to (AR determines class from _type column)
        unless assoc.polymorphic
          if assoc.lcp_model?
            opts[:class_name] = assoc.resolved_class_name
          elsif assoc.class_name
            opts[:class_name] = assoc.class_name
          end
        end
        opts[:foreign_key] = assoc.foreign_key if assoc.foreign_key && assoc.type == "belongs_to" && !assoc.polymorphic
        opts
      end

      def apply_common_options(opts, assoc)
        opts[:inverse_of] = assoc.inverse_of if assoc.inverse_of
        opts[:autosave] = assoc.autosave unless assoc.autosave.nil?
        opts[:validate] = assoc.validate unless assoc.validate.nil?
      end
    end
  end
end
