module LcpRuby
  module BulkUpdater
    # Performs update_all on a scope and yields metadata for callers
    # that need to react (e.g., auditing, event dispatch).
    #
    # @param scope [ActiveRecord::Relation] the records to update
    # @param updates [Hash] attribute changes to apply
    # @param action [Symbol] semantic action name (e.g., :bulk_update, :batch_discard)
    # @param model_definition [ModelDefinition] the model's metadata
    # @yield [affected_ids, updates, action] optional block for post-update hooks
    # @return [Integer] number of affected rows
    def self.tracked_update_all(scope, updates, action: :bulk_update, model_definition:)
      if block_given?
        affected_ids = scope.pluck(:id)
        return 0 if affected_ids.empty?

        result = scope.update_all(updates)
        yield(affected_ids, updates, action)
        result
      else
        scope.update_all(updates)
      end
    end
  end
end
