require "spec_helper"

RSpec.describe LcpRuby::Types::Transforms::Strip do
  subject(:transform) { described_class.new }

  it "strips leading and trailing whitespace" do
    expect(transform.call("  hello  ")).to eq("hello")
  end

  it "returns nil for nil input" do
    expect(transform.call(nil)).to be_nil
  end

  it "handles empty string" do
    expect(transform.call("")).to eq("")
  end

  it "strips tabs and newlines" do
    expect(transform.call("\thello\n")).to eq("hello")
  end
end
