require "spec_helper"

RSpec.describe LcpRuby::Types::Transforms::Downcase do
  subject(:transform) { described_class.new }

  it "downcases a string" do
    expect(transform.call("HELLO")).to eq("hello")
  end

  it "returns nil for nil input" do
    expect(transform.call(nil)).to be_nil
  end

  it "handles mixed case" do
    expect(transform.call("HeLLo WoRLd")).to eq("hello world")
  end

  it "handles empty string" do
    expect(transform.call("")).to eq("")
  end
end
