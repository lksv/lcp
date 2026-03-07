require "spec_helper"

RSpec.describe LcpRuby::DataSource::Base do
  subject { described_class.new }

  describe "#find" do
    it "raises NotImplementedError" do
      expect { subject.find(1) }.to raise_error(NotImplementedError)
    end
  end

  describe "#search" do
    it "raises NotImplementedError" do
      expect { subject.search }.to raise_error(NotImplementedError)
    end
  end

  describe "#find_many" do
    it "calls find for each id by default" do
      allow(subject).to receive(:find).with(1).and_return("rec1")
      allow(subject).to receive(:find).with(2).and_raise(LcpRuby::DataSource::RecordNotFound)
      allow(subject).to receive(:find).with(3).and_return("rec3")

      result = subject.find_many([ 1, 2, 3 ])
      expect(result).to eq([ "rec1", "rec3" ])
    end
  end

  describe "#count" do
    it "delegates to search" do
      result = LcpRuby::SearchResult.new(records: [], total_count: 42)
      allow(subject).to receive(:search).and_return(result)
      expect(subject.count).to eq(42)
    end
  end

  describe "#save" do
    it "raises ReadonlyError" do
      expect { subject.save(double) }.to raise_error(LcpRuby::DataSource::ReadonlyError)
    end
  end

  describe "#destroy" do
    it "raises ReadonlyError" do
      expect { subject.destroy(1) }.to raise_error(LcpRuby::DataSource::ReadonlyError)
    end
  end

  describe "#writable?" do
    it "returns false" do
      expect(subject.writable?).to be false
    end
  end

  describe "#supported_operators" do
    it "returns default operator set" do
      ops = subject.supported_operators
      expect(ops).to include("eq", "cont", "gt", "lt")
    end
  end
end
