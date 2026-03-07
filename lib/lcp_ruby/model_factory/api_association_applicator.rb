module LcpRuby
  module ModelFactory
    # Applies cross-source associations between DB and API models.
    # Runs after all models are registered and data sources attached.
    #
    # Handles 4 patterns:
    # - DB belongs_to API:  lazy accessor with instance cache, error → placeholder
    # - API belongs_to DB:  lazy accessor calling TargetModel.find(fk_value)
    # - DB has_many API:    lazy accessor calling target data source search
    # - API has_many DB:    accessor calling TargetModel.where(fk: self.id)
    class ApiAssociationApplicator
      def initialize(loader)
        @loader = loader
      end

      def apply!
        @loader.model_definitions.each_value do |model_def|
          next if model_def.virtual?

          model_class = LcpRuby.registry.model_for(model_def.name)
          next unless model_class

          source_is_api = model_def.api_model?

          model_def.associations.each do |assoc|
            target_def = @loader.model_definitions[assoc.target_model]
            next unless target_def

            target_is_api = target_def.api_model?

            # Only handle cross-source or API-to-API associations
            next if !source_is_api && !target_is_api

            case assoc.type
            when "belongs_to"
              apply_belongs_to(model_class, model_def, assoc, target_def, source_is_api, target_is_api)
            when "has_many"
              apply_has_many(model_class, model_def, assoc, target_def, source_is_api, target_is_api)
            end
          end
        end
      end

      private

      def apply_belongs_to(model_class, model_def, assoc, target_def, source_is_api, target_is_api)
        assoc_name = assoc.name.to_sym
        fk = assoc.foreign_key
        target_model_name = assoc.target_model

        if target_is_api
          # Source (DB or API) belongs_to API target → lazy accessor via data source
          model_class.define_method(assoc_name) do
            ivar = :"@_api_assoc_#{assoc_name}"
            return instance_variable_get(ivar) if instance_variable_defined?(ivar)

            fk_value = respond_to?(fk) ? send(fk) : self[fk]
            return nil if fk_value.blank?

            target_class = LcpRuby.registry.model_for(target_model_name)
            result = target_class.find(fk_value)
            instance_variable_set(ivar, result)
            result
          rescue DataSource::RecordNotFound, DataSource::ConnectionError
            placeholder = DataSource::ApiErrorPlaceholder.new(id: fk_value, model_name: target_model_name)
            instance_variable_set(ivar, placeholder)
            placeholder
          end
        elsif source_is_api && !target_is_api
          # API belongs_to DB target → lazy accessor via AR find
          model_class.define_method(assoc_name) do
            ivar = :"@_api_assoc_#{assoc_name}"
            return instance_variable_get(ivar) if instance_variable_defined?(ivar)

            fk_value = respond_to?(fk) ? send(fk) : nil
            return nil if fk_value.blank?

            target_class = LcpRuby.registry.model_for(target_model_name)
            result = target_class.find_by(id: fk_value)
            instance_variable_set(ivar, result)
            result
          end
        end
      end

      def apply_has_many(model_class, model_def, assoc, target_def, source_is_api, target_is_api)
        assoc_name = assoc.name.to_sym
        fk = assoc.foreign_key || "#{model_def.name}_id"
        target_model_name = assoc.target_model

        if source_is_api && !target_is_api
          # API has_many DB records → AR where query
          model_class.define_method(assoc_name) do
            target_class = LcpRuby.registry.model_for(target_model_name)
            target_class.where(fk => id)
          end
        elsif !source_is_api && target_is_api
          # DB has_many API records → data source search
          model_class.define_method(assoc_name) do
            ivar = :"@_api_assoc_#{assoc_name}"
            return instance_variable_get(ivar) if instance_variable_defined?(ivar)

            target_class = LcpRuby.registry.model_for(target_model_name)
            result = target_class.lcp_search(
              filters: [ { field: fk, operator: "eq", value: id } ],
              per: 1000
            )
            records = result.to_a
            instance_variable_set(ivar, records)
            records
          rescue DataSource::ConnectionError
            instance_variable_set(ivar, [])
            []
          end
        end
      end
    end
  end
end
