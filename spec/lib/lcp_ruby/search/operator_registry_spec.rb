require "spec_helper"

RSpec.describe LcpRuby::Search::OperatorRegistry do
  describe ".operators_for" do
    it "returns string operators" do
      ops = described_class.operators_for(:string)
      expect(ops).to include(:eq, :not_eq, :cont, :not_cont, :start, :end, :in, :not_in, :present, :blank)
    end

    it "returns text operators (subset of string)" do
      ops = described_class.operators_for(:text)
      expect(ops).to include(:cont, :not_cont, :present, :blank)
      expect(ops).not_to include(:eq, :start, :end, :in)
    end

    it "returns integer operators with numeric comparisons" do
      ops = described_class.operators_for(:integer)
      expect(ops).to include(:eq, :gt, :gteq, :lt, :lteq, :between, :in, :not_in)
      expect(ops).not_to include(:cont, :start, :end)
    end

    it "returns float operators without in/not_in" do
      ops = described_class.operators_for(:float)
      expect(ops).to include(:eq, :gt, :gteq, :lt, :lteq, :between)
      expect(ops).not_to include(:in, :not_in, :cont)
    end

    it "returns decimal operators matching float" do
      expect(described_class.operators_for(:decimal)).to eq(described_class.operators_for(:float))
    end

    it "returns boolean operators" do
      ops = described_class.operators_for(:boolean)
      expect(ops).to include(:true, :not_true, :false, :not_false, :null, :not_null)
      expect(ops).not_to include(:eq, :cont, :gt)
    end

    it "returns date operators with relative dates" do
      ops = described_class.operators_for(:date)
      expect(ops).to include(:eq, :gt, :gteq, :lt, :lteq, :between)
      expect(ops).to include(:last_n_days, :this_week, :this_month, :this_quarter, :this_year)
    end

    it "returns datetime operators matching date" do
      expect(described_class.operators_for(:datetime)).to eq(described_class.operators_for(:date))
    end

    it "returns enum operators" do
      ops = described_class.operators_for(:enum)
      expect(ops).to include(:eq, :not_eq, :in, :not_in, :present, :blank)
      expect(ops).not_to include(:cont, :gt, :between)
    end

    it "returns uuid operators" do
      ops = described_class.operators_for(:uuid)
      expect(ops).to include(:eq, :not_eq, :in, :not_in, :present, :blank)
    end

    it "returns empty array for unknown type" do
      expect(described_class.operators_for(:unknown)).to eq([])
    end

    it "accepts string type argument" do
      expect(described_class.operators_for("string")).to eq(described_class.operators_for(:string))
    end
  end

  describe ".label_for" do
    it "returns default label for known operator" do
      expect(described_class.label_for(:eq)).to eq("equals")
      expect(described_class.label_for(:cont)).to eq("contains")
      expect(described_class.label_for(:gt)).to eq("greater than")
    end

    it "returns humanized fallback for unknown operator" do
      expect(described_class.label_for(:custom_op)).to eq("Custom op")
    end

    it "accepts string argument" do
      expect(described_class.label_for("eq")).to eq("equals")
    end

    it "uses i18n override when available" do
      allow(I18n).to receive(:t)
        .with("lcp_ruby.search.operators.eq", default: "equals")
        .and_return("is equal to")

      expect(described_class.label_for(:eq)).to eq("is equal to")
    end
  end

  describe ".no_value?" do
    it "returns true for no-value operators" do
      %i[present blank null not_null true not_true false not_false
         this_week this_month this_quarter this_year].each do |op|
        expect(described_class.no_value?(op)).to be(true), "Expected #{op} to be no_value"
      end
    end

    it "returns false for value-requiring operators" do
      %i[eq cont gt between in last_n_days].each do |op|
        expect(described_class.no_value?(op)).to be(false), "Expected #{op} not to be no_value"
      end
    end
  end

  describe ".multi_value?" do
    it "returns true for in and not_in" do
      expect(described_class.multi_value?(:in)).to be true
      expect(described_class.multi_value?(:not_in)).to be true
    end

    it "returns false for single-value operators" do
      expect(described_class.multi_value?(:eq)).to be false
      expect(described_class.multi_value?(:cont)).to be false
    end
  end

  describe ".range?" do
    it "returns true for between" do
      expect(described_class.range?(:between)).to be true
    end

    it "returns false for non-range operators" do
      expect(described_class.range?(:eq)).to be false
    end
  end

  describe ".parameterized?" do
    it "returns true for last_n_days" do
      expect(described_class.parameterized?(:last_n_days)).to be true
    end

    it "returns false for non-parameterized operators" do
      expect(described_class.parameterized?(:eq)).to be false
      expect(described_class.parameterized?(:this_month)).to be false
    end
  end

  describe ".relative_date?" do
    it "returns true for relative date operators" do
      %i[last_n_days this_week this_month this_quarter this_year].each do |op|
        expect(described_class.relative_date?(op)).to be(true), "Expected #{op} to be relative_date"
      end
    end

    it "returns false for absolute operators" do
      %i[eq gt between present].each do |op|
        expect(described_class.relative_date?(op)).to be(false), "Expected #{op} not to be relative_date"
      end
    end
  end
end
