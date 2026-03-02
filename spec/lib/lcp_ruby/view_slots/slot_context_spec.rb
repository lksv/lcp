require "spec_helper"

RSpec.describe LcpRuby::ViewSlots::SlotContext do
  describe "#initialize" do
    it "stores all attributes correctly" do
      presenter = double("presenter")
      model_def = double("model_definition")
      evaluator = double("evaluator")
      action_set = double("action_set")
      params = { filter: "active" }
      records = [ double("record1") ]
      record = double("record2")
      locals = { manage_path: "/manage" }

      context = described_class.new(
        presenter: presenter,
        model_definition: model_def,
        evaluator: evaluator,
        action_set: action_set,
        params: params,
        records: records,
        record: record,
        locals: locals
      )

      expect(context.presenter).to eq(presenter)
      expect(context.model_definition).to eq(model_def)
      expect(context.evaluator).to eq(evaluator)
      expect(context.action_set).to eq(action_set)
      expect(context.params).to eq(params)
      expect(context.records).to eq(records)
      expect(context.record).to eq(record)
      expect(context.locals).to eq(locals)
    end

    it "defaults locals to empty hash" do
      context = described_class.new(
        presenter: nil, model_definition: nil, evaluator: nil,
        action_set: nil, params: {}
      )

      expect(context.locals).to eq({})
    end

    it "defaults records and record to nil" do
      context = described_class.new(
        presenter: nil, model_definition: nil, evaluator: nil,
        action_set: nil, params: {}
      )

      expect(context.records).to be_nil
      expect(context.record).to be_nil
    end
  end
end
