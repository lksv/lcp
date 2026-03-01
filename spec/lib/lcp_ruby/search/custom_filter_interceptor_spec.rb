require "spec_helper"

RSpec.describe LcpRuby::Search::CustomFilterInterceptor do
  let(:model_class) { Class.new(ActiveRecord::Base) }
  let(:evaluator) { double("PermissionEvaluator") }
  let(:scope) { double("ActiveRecord::Relation") }

  before do
    # Make scope behave like a relation
    allow(scope).to receive(:is_a?).with(ActiveRecord::Relation).and_return(true)
  end

  describe ".apply" do
    it "returns scope and params unchanged when no filter methods exist" do
      params = { "name_cont" => "Alice", "age_gt" => "30" }
      result_scope, remaining = described_class.apply(scope, params, model_class, evaluator)

      expect(result_scope).to eq(scope)
      expect(remaining).to eq(params)
    end

    it "returns scope and params unchanged when params are blank" do
      result_scope, remaining = described_class.apply(scope, {}, model_class, evaluator)
      expect(result_scope).to eq(scope)
      expect(remaining).to eq({})
    end

    it "returns scope and params unchanged when params are nil" do
      result_scope, remaining = described_class.apply(scope, nil, model_class, evaluator)
      expect(result_scope).to eq(scope)
      expect(remaining).to be_nil
    end

    context "with a custom filter method" do
      let(:filtered_scope) { double("FilteredRelation") }

      before do
        allow(filtered_scope).to receive(:is_a?).with(ActiveRecord::Relation).and_return(true)

        model_class.define_singleton_method(:filter_active) do |s, value, _eval|
          s # just return scope for testing
        end
      end

      it "calls the filter method and removes the key from remaining params" do
        allow(model_class).to receive(:filter_active).with(scope, "true", evaluator).and_return(filtered_scope)

        params = { "active" => "true", "name_cont" => "Alice" }
        result_scope, remaining = described_class.apply(scope, params, model_class, evaluator)

        expect(result_scope).to eq(filtered_scope)
        expect(remaining).to eq("name_cont" => "Alice")
      end

      it "passes scope, value, and evaluator to the filter method" do
        expect(model_class).to receive(:filter_active).with(scope, "yes", evaluator).and_return(filtered_scope)

        described_class.apply(scope, { "active" => "yes" }, model_class, evaluator)
      end
    end

    context "when filter method returns non-Relation" do
      before do
        model_class.define_singleton_method(:filter_bad) do |_s, _value, _eval|
          "not a relation"
        end
      end

      it "skips the filter and keeps the key in remaining params" do
        allow(Rails.logger).to receive(:warn)

        params = { "bad" => "value" }
        result_scope, remaining = described_class.apply(scope, params, model_class, evaluator)

        expect(result_scope).to eq(scope)
        expect(remaining).to eq(params)
      end

      it "logs a warning" do
        expect(Rails.logger).to receive(:warn).with(/filter_bad.*did not return ActiveRecord::Relation/)

        described_class.apply(scope, { "bad" => "value" }, model_class, evaluator)
      end
    end

    context "with inherited methods from ActiveRecord::Base" do
      it "does not call methods inherited from ActiveRecord::Base" do
        # ActiveRecord::Base has many methods; filter_ prefix methods
        # defined there should not be intercepted
        allow(ActiveRecord::Base).to receive(:respond_to?).and_call_original
        allow(ActiveRecord::Base).to receive(:respond_to?).with("filter_inherited").and_return(true)
        allow(model_class).to receive(:respond_to?).with("filter_inherited").and_return(true)

        params = { "inherited" => "value" }
        _result_scope, remaining = described_class.apply(scope, params, model_class, evaluator)

        expect(remaining).to eq(params)
      end
    end

    context "with multiple filter methods" do
      let(:scope1) { double("Scope1") }
      let(:scope2) { double("Scope2") }

      before do
        allow(scope1).to receive(:is_a?).with(ActiveRecord::Relation).and_return(true)
        allow(scope2).to receive(:is_a?).with(ActiveRecord::Relation).and_return(true)

        model_class.define_singleton_method(:filter_status) do |s, _value, _eval|
          s
        end
        model_class.define_singleton_method(:filter_priority) do |s, _value, _eval|
          s
        end
      end

      it "chains filter methods and removes all intercepted keys" do
        allow(model_class).to receive(:filter_status).and_return(scope1)
        allow(model_class).to receive(:filter_priority).and_return(scope2)

        params = { "status" => "open", "priority" => "high", "name_cont" => "Alice" }
        _result_scope, remaining = described_class.apply(scope, params, model_class, evaluator)

        expect(remaining).to eq("name_cont" => "Alice")
      end
    end
  end

  describe ".own_filter_method?" do
    it "returns true when model class defines the method" do
      model_class.define_singleton_method(:filter_test) { |*| }
      expect(described_class.own_filter_method?(model_class, "filter_test")).to be true
    end

    it "returns false when model class does not respond to the method" do
      expect(described_class.own_filter_method?(model_class, "filter_nonexistent")).to be false
    end

    it "returns false when method exists on ActiveRecord::Base" do
      # Simulate a method that exists on both model and AR::Base
      allow(model_class).to receive(:respond_to?).with("filter_ar_method").and_return(true)
      allow(ActiveRecord::Base).to receive(:respond_to?).with("filter_ar_method").and_return(true)

      expect(described_class.own_filter_method?(model_class, "filter_ar_method")).to be false
    end
  end
end
