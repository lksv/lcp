require "spec_helper"

RSpec.describe LcpRuby::HashUtils do
  describe ".stringify_deep" do
    it "converts symbol keys to strings" do
      expect(described_class.stringify_deep({ foo: "bar" })).to eq({ "foo" => "bar" })
    end

    it "converts nested hash symbol keys" do
      input = { outer: { inner: "value" } }
      expected = { "outer" => { "inner" => "value" } }
      expect(described_class.stringify_deep(input)).to eq(expected)
    end

    it "converts symbol values to strings" do
      expect(described_class.stringify_deep({ foo: :bar })).to eq({ "foo" => "bar" })
    end

    it "recurses into arrays" do
      input = [{ foo: :bar }, { baz: "qux" }]
      expected = [{ "foo" => "bar" }, { "baz" => "qux" }]
      expect(described_class.stringify_deep(input)).to eq(expected)
    end

    it "passes through strings unchanged" do
      expect(described_class.stringify_deep("hello")).to eq("hello")
    end

    it "passes through integers unchanged" do
      expect(described_class.stringify_deep(42)).to eq(42)
    end

    it "passes through nil unchanged" do
      expect(described_class.stringify_deep(nil)).to be_nil
    end

    it "passes through booleans unchanged" do
      expect(described_class.stringify_deep(true)).to eq(true)
      expect(described_class.stringify_deep(false)).to eq(false)
    end

    it "handles deeply nested mixed structures" do
      input = { a: [{ b: :c }, "d"], e: { f: { g: :h } } }
      expected = { "a" => [{ "b" => "c" }, "d"], "e" => { "f" => { "g" => "h" } } }
      expect(described_class.stringify_deep(input)).to eq(expected)
    end

    it "handles already-stringified hashes" do
      input = { "already" => "stringified" }
      expect(described_class.stringify_deep(input)).to eq({ "already" => "stringified" })
    end
  end
end
