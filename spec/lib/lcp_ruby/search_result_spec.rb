require "spec_helper"

RSpec.describe LcpRuby::SearchResult do
  let(:records) { [ double(id: 1), double(id: 2), double(id: 3) ] }

  describe "basic functionality" do
    subject { described_class.new(records: records, total_count: 100, current_page: 2, per_page: 25) }

    it "includes Enumerable" do
      expect(described_class.ancestors).to include(Enumerable)
    end

    it "returns records via each" do
      collected = []
      subject.each { |r| collected << r }
      expect(collected).to eq(records)
    end

    it "returns size" do
      expect(subject.size).to eq(3)
      expect(subject.length).to eq(3)
    end

    it "returns empty?" do
      expect(subject.empty?).to be false
    end

    it "returns to_a" do
      expect(subject.to_a).to eq(records)
      expect(subject.to_a).not_to equal(records) # returns a copy
    end
  end

  describe "pagination" do
    subject { described_class.new(records: records, total_count: 100, current_page: 2, per_page: 25) }

    it "calculates total_pages" do
      expect(subject.total_pages).to eq(4)
    end

    it "rounds total_pages up" do
      result = described_class.new(records: [], total_count: 101, per_page: 25)
      expect(result.total_pages).to eq(5)
    end

    it "returns limit_value" do
      expect(subject.limit_value).to eq(25)
    end

    it "detects first_page?" do
      expect(subject.first_page?).to be false
      first = described_class.new(records: records, total_count: 100, current_page: 1, per_page: 25)
      expect(first.first_page?).to be true
    end

    it "detects last_page?" do
      expect(subject.last_page?).to be false
      last = described_class.new(records: records, total_count: 100, current_page: 4, per_page: 25)
      expect(last.last_page?).to be true
    end

    it "returns count as total_count" do
      expect(subject.count).to eq(100)
    end

    it "handles zero total_count" do
      empty = described_class.new(records: [], total_count: 0)
      expect(empty.total_pages).to eq(0)
      expect(empty.first_page?).to be true
      expect(empty.last_page?).to be true
    end
  end

  describe "error state" do
    it "defaults to non-error" do
      result = described_class.new(records: records, total_count: 3)
      expect(result.error?).to be false
      expect(result.stale?).to be false
      expect(result.message).to be_nil
    end

    it "marks as error" do
      result = described_class.new(records: [], total_count: 0, error: true, message: "API down")
      expect(result.error?).to be true
      expect(result.message).to eq("API down")
    end

    it "marks as stale" do
      result = described_class.new(records: records, total_count: 3, stale: true, message: "Cached")
      expect(result.stale?).to be true
      expect(result.message).to eq("Cached")
    end
  end

  describe "defaults" do
    it "defaults current_page to 1" do
      result = described_class.new(records: [], total_count: 0, current_page: 0)
      expect(result.current_page).to eq(1)
    end

    it "defaults per_page to 1 minimum" do
      result = described_class.new(records: [], total_count: 0, per_page: 0)
      expect(result.per_page).to eq(1)
    end

    it "wraps nil records as empty array" do
      result = described_class.new(records: nil, total_count: 0)
      expect(result.records).to eq([])
    end
  end
end
