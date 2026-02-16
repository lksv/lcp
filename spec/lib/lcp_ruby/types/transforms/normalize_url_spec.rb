require "spec_helper"

RSpec.describe LcpRuby::Types::Transforms::NormalizeUrl do
  subject(:transform) { described_class.new }

  it "prepends https:// when no scheme is present" do
    expect(transform.call("example.com")).to eq("https://example.com")
  end

  it "preserves existing https://" do
    expect(transform.call("https://example.com")).to eq("https://example.com")
  end

  it "preserves existing http://" do
    expect(transform.call("http://example.com")).to eq("http://example.com")
  end

  it "preserves ftp:// scheme" do
    expect(transform.call("ftp://files.example.com")).to eq("ftp://files.example.com")
  end

  it "returns nil for nil input" do
    expect(transform.call(nil)).to be_nil
  end

  it "returns empty string for empty input" do
    expect(transform.call("")).to eq("")
  end

  it "strips surrounding whitespace before checking scheme" do
    expect(transform.call("  example.com  ")).to eq("https://example.com")
  end
end
