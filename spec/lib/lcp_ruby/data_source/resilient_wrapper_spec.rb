require "spec_helper"

RSpec.describe LcpRuby::DataSource::ResilientWrapper do
  let(:inner) { instance_double(LcpRuby::DataSource::Base) }

  subject { described_class.new(inner, model_name: "test_model") }

  describe "#find" do
    it "returns result on success" do
      record = double(id: "1")
      allow(inner).to receive(:find).with("1").and_return(record)

      expect(subject.find("1")).to eq(record)
    end

    it "returns ApiErrorPlaceholder on ConnectionError" do
      allow(inner).to receive(:find).with("1").and_raise(
        LcpRuby::DataSource::ConnectionError, "timeout"
      )

      result = subject.find("1")
      expect(result).to be_a(LcpRuby::DataSource::ApiErrorPlaceholder)
      expect(result.id).to eq("1")
      expect(result.error?).to be true
    end
  end

  describe "#find_many" do
    it "returns placeholders on ConnectionError" do
      allow(inner).to receive(:find_many).and_raise(
        LcpRuby::DataSource::ConnectionError, "timeout"
      )

      result = subject.find_many([ "1", "2" ])
      expect(result).to all(be_a(LcpRuby::DataSource::ApiErrorPlaceholder))
      expect(result.size).to eq(2)
    end
  end

  describe "#search" do
    it "returns result on success" do
      sr = LcpRuby::SearchResult.new(records: [], total_count: 0)
      allow(inner).to receive(:search).and_return(sr)

      expect(subject.search).to eq(sr)
    end

    it "returns error SearchResult on ConnectionError" do
      allow(inner).to receive(:search).and_raise(
        LcpRuby::DataSource::ConnectionError, "timeout"
      )

      result = subject.search({}, page: 2, per: 10)
      expect(result).to be_a(LcpRuby::SearchResult)
      expect(result.error?).to be true
      expect(result.records).to be_empty
      expect(result.current_page).to eq(2)
    end
  end

  describe "#count" do
    it "returns 0 on ConnectionError" do
      allow(inner).to receive(:count).and_raise(
        LcpRuby::DataSource::ConnectionError, "timeout"
      )

      expect(subject.count).to eq(0)
    end
  end

  describe "#select_options" do
    it "returns empty array on ConnectionError" do
      allow(inner).to receive(:select_options).and_raise(
        LcpRuby::DataSource::ConnectionError, "timeout"
      )

      expect(subject.select_options).to eq([])
    end
  end
end
