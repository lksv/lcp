require "spec_helper"

RSpec.describe LcpRuby::ModelFactory::ArrayType do
  describe "string item_type" do
    subject(:type) { described_class.new("string") }

    describe "#cast" do
      it "casts an Array" do
        expect(type.cast(%w[a b c])).to eq(%w[a b c])
      end

      it "casts a JSON string" do
        expect(type.cast('["a","b"]')).to eq(%w[a b])
      end

      it "falls back to comma split for non-JSON string" do
        expect(type.cast("a, b, c")).to eq(%w[a b c])
      end

      it "rejects blank items from array" do
        expect(type.cast([ "a", "", "b" ])).to eq(%w[a b])
      end

      it "casts nil to empty array" do
        expect(type.cast(nil)).to eq([])
      end

      it "wraps single value" do
        expect(type.cast(42)).to eq([ "42" ])
      end
    end

    describe "#deserialize" do
      it "deserializes JSON string to array" do
        expect(type.deserialize('["x","y"]')).to eq(%w[x y])
      end

      it "raises on invalid JSON in non-production" do
        expect { type.deserialize("not json") }.to raise_error(JSON::ParserError)
      end

      it "returns empty array for nil" do
        expect(type.deserialize(nil)).to eq([])
      end

      it "passes through an Array" do
        expect(type.deserialize(%w[a b])).to eq(%w[a b])
      end

      it "returns empty array for non-array JSON" do
        expect(type.deserialize('{"a":1}')).to eq([])
      end
    end

    describe "#serialize" do
      it "serializes array to JSON" do
        expect(type.serialize(%w[a b])).to eq('["a","b"]')
      end

      it "serializes non-array to empty JSON array" do
        expect(type.serialize(nil)).to eq("[]")
      end
    end

    describe "#changed_in_place?" do
      it "detects changes" do
        expect(type.changed_in_place?('["a"]', %w[a b])).to be true
      end

      it "detects no changes" do
        expect(type.changed_in_place?('["a","b"]', %w[a b])).to be false
      end
    end
  end

  describe "integer item_type" do
    subject(:type) { described_class.new("integer") }

    it "casts string items to integers" do
      expect(type.cast([ "1", "2", "3" ])).to eq([ 1, 2, 3 ])
    end

    it "casts JSON string with integers" do
      expect(type.cast("[1,2,3]")).to eq([ 1, 2, 3 ])
    end

    it "deserializes to integers" do
      expect(type.deserialize('[1,2,3]')).to eq([ 1, 2, 3 ])
    end
  end

  describe "float item_type" do
    subject(:type) { described_class.new("float") }

    it "casts string items to floats" do
      expect(type.cast([ "1.5", "2.7" ])).to eq([ 1.5, 2.7 ])
    end

    it "deserializes to floats" do
      expect(type.deserialize('[1.5,2.7]')).to eq([ 1.5, 2.7 ])
    end
  end
end
