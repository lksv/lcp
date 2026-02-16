require "spec_helper"

RSpec.describe LcpRuby::Types::Transforms::NormalizePhone do
  subject(:transform) { described_class.new }

  it "strips non-digit characters" do
    expect(transform.call("(123) 456-7890")).to eq("1234567890")
  end

  it "preserves leading +" do
    expect(transform.call("+1 (555) 123-4567")).to eq("+15551234567")
  end

  it "returns nil for nil input" do
    expect(transform.call(nil)).to be_nil
  end

  it "returns empty string for empty input" do
    expect(transform.call("")).to eq("")
  end

  it "strips whitespace" do
    expect(transform.call("  +420 123 456 789  ")).to eq("+420123456789")
  end

  it "handles digits-only input" do
    expect(transform.call("1234567890")).to eq("1234567890")
  end
end
