module LcpRuby
  module ViewSlots
    class SlotContext
      attr_reader :presenter, :model_definition, :evaluator, :action_set,
                  :params, :records, :record, :locals

      def initialize(presenter:, model_definition:, evaluator:, action_set:,
                     params:, records: nil, record: nil, locals: {})
        @presenter = presenter
        @model_definition = model_definition
        @evaluator = evaluator
        @action_set = action_set
        @params = params
        @records = records
        @record = record
        @locals = locals
      end
    end
  end
end
