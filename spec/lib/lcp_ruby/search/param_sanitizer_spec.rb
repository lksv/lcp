require "spec_helper"

RSpec.describe LcpRuby::Search::ParamSanitizer do
  describe ".reject_blanks" do
    it "removes keys with blank string values" do
      result = described_class.reject_blanks("name" => "Alice", "email" => "", "city" => "Prague")
      expect(result).to eq("name" => "Alice", "city" => "Prague")
    end

    it "preserves nil values" do
      result = described_class.reject_blanks("name" => nil, "email" => "a@b.com")
      expect(result).to eq("name" => nil, "email" => "a@b.com")
    end

    it "preserves false values" do
      result = described_class.reject_blanks("active" => false, "name" => "Alice")
      expect(result).to eq("active" => false, "name" => "Alice")
    end

    it "preserves zero values" do
      result = described_class.reject_blanks("count" => 0, "name" => "Alice")
      expect(result).to eq("count" => 0, "name" => "Alice")
    end

    it "returns empty hash for nil input" do
      expect(described_class.reject_blanks(nil)).to eq({})
    end

    it "returns empty hash for empty hash input" do
      expect(described_class.reject_blanks({})).to eq({})
    end

    it "removes whitespace-only strings" do
      result = described_class.reject_blanks("name" => "  ", "email" => "a@b.com")
      expect(result).to eq("email" => "a@b.com")
    end
  end

  describe ".normalize_boolean" do
    LcpRuby::Search::ParamSanitizer::TRUTHY.each do |truthy|
      it "normalizes '#{truthy}' to true" do
        expect(described_class.normalize_boolean(truthy)).to be true
      end
    end

    LcpRuby::Search::ParamSanitizer::FALSY.each do |falsy|
      it "normalizes '#{falsy}' to false" do
        expect(described_class.normalize_boolean(falsy)).to be false
      end
    end

    it "is case-insensitive" do
      expect(described_class.normalize_boolean("TRUE")).to be true
      expect(described_class.normalize_boolean("False")).to be false
      expect(described_class.normalize_boolean("YES")).to be true
    end

    it "returns the original value for non-boolean strings" do
      expect(described_class.normalize_boolean("maybe")).to eq("maybe")
      expect(described_class.normalize_boolean("2")).to eq("2")
    end

    it "returns the original value for non-string types" do
      expect(described_class.normalize_boolean(42)).to eq(42)
      expect(described_class.normalize_boolean(nil)).to eq(nil)
    end
  end
end
