module LcpRuby
  module Sequences
    GLOBAL_SCOPE_KEY = "_global"

    # Build a scope key string from a key-value hash.
    # Used by both SequenceApplicator (at increment time) and SequenceManager (admin API).
    def self.build_scope_key(scope_hash)
      return GLOBAL_SCOPE_KEY if scope_hash.nil? || scope_hash.empty?

      scope_hash.map { |key, value| "#{key}:#{value}" }.join("/")
    end

    class SequenceManager
      # Set the current counter value for a specific model/field/scope combination.
      def self.set(model:, field:, scope: {}, value:)
        counter_model = LcpRuby.registry.model_for("gapfree_sequence")
        scope_key = Sequences.build_scope_key(scope)

        row = counter_model.find_or_initialize_by(
          seq_model: model.to_s,
          seq_field: field.to_s,
          scope_key: scope_key
        )
        row.current_value = value
        row.save!
        row
      end

      # Get the current counter value for a specific model/field/scope combination.
      def self.current(model:, field:, scope: {})
        counter_model = LcpRuby.registry.model_for("gapfree_sequence")
        scope_key = Sequences.build_scope_key(scope)

        row = counter_model.find_by(
          seq_model: model.to_s,
          seq_field: field.to_s,
          scope_key: scope_key
        )
        row&.current_value
      end

      # List all counter rows, optionally filtered by model name.
      def self.list(model: nil)
        counter_model = LcpRuby.registry.model_for("gapfree_sequence")
        scope = counter_model.all
        scope = scope.where(seq_model: model.to_s) if model
        scope.order(:seq_model, :seq_field, :scope_key)
      end
    end
  end
end
