require "spec_helper"

CacheTestRecord = Struct.new(:id, :name, keyword_init: true)

RSpec.describe LcpRuby::DataSource::CachedWrapper do
  let(:record) { CacheTestRecord.new(id: "1", name: "Test") }
  let(:search_result) do
    LcpRuby::SearchResult.new(records: [ record ], total_count: 1)
  end

  let(:inner) do
    dbl = double("inner_adapter")
    allow(dbl).to receive(:writable?).and_return(false)
    allow(dbl).to receive(:supported_operators).and_return(%w[eq cont])
    dbl
  end

  subject { described_class.new(inner, model_name: "cached_test_model", ttl: 60, list_ttl: 30) }

  before { Rails.cache.clear }

  describe "#find" do
    it "caches results" do
      expect(inner).to receive(:find).with("1").once.and_return(record)

      result1 = subject.find("1")
      result2 = subject.find("1")

      expect(result1).to eq(record)
      expect(result2).to eq(record)
    end

    it "returns placeholder when cache empty and connection fails" do
      allow(inner).to receive(:find).with("1").and_raise(
        LcpRuby::DataSource::ConnectionError, "timeout"
      )

      result = subject.find("1")
      expect(result).to be_a(LcpRuby::DataSource::ApiErrorPlaceholder)
    end
  end

  describe "#search" do
    it "caches search results" do
      expect(inner).to receive(:search)
        .with({}, sort: nil, page: 1, per: 25)
        .once.and_return(search_result)

      result1 = subject.search({}, sort: nil, page: 1, per: 25)
      result2 = subject.search({}, sort: nil, page: 1, per: 25)

      expect(result1.total_count).to eq(1)
      expect(result2.total_count).to eq(1)
    end
  end

  describe "#writable?" do
    it "delegates to inner" do
      expect(subject.writable?).to be false
    end
  end

  describe "#supported_operators" do
    it "delegates to inner" do
      expect(subject.supported_operators).to eq(%w[eq cont])
    end
  end
end
