module LcpRuby
  module DataSource
    # Batch preloads API associations to prevent N+1 data source calls.
    # Collects FK values from records, makes a single find_many call,
    # and distributes results via instance variables.
    class ApiPreloader
      # @param records [Array] records to preload associations for
      # @param assoc_name [String, Symbol] the association name
      # @param assoc_def [AssociationDefinition] the association metadata
      def self.preload(records, assoc_name, assoc_def)
        return if records.blank?

        target_model_name = assoc_def.target_model
        target_def = LcpRuby.loader.model_definitions[target_model_name]
        return unless target_def&.api_model?

        fk = assoc_def.foreign_key
        return unless fk

        target_class = LcpRuby.registry.model_for(target_model_name)
        return unless target_class.respond_to?(:lcp_api_model?) && target_class.lcp_api_model?

        # Collect unique FK values
        fk_values = records.filter_map do |r|
          r.respond_to?(fk) ? r.send(fk) : r[fk]
        end.uniq.compact

        return if fk_values.empty?

        # Batch fetch
        fetched = target_class.find_many(fk_values)
        by_id = fetched.index_by { |r| r.id.to_s }

        # Distribute to records via instance variables
        ivar = :"@_api_assoc_#{assoc_name}"
        records.each do |record|
          fk_value = record.respond_to?(fk) ? record.send(fk) : record[fk]
          target = fk_value ? by_id[fk_value.to_s] : nil
          record.instance_variable_set(ivar, target)
        end
      end
    end
  end
end
