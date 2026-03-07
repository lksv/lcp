require "spec_helper"

RSpec.describe LcpRuby::DataSource::ApiErrorPlaceholder do
  subject { described_class.new(id: 42, model_name: "Building") }

  it "returns formatted label" do
    expect(subject.to_label).to eq("Building #42 (unavailable)")
  end

  it "returns to_s as to_label" do
    expect(subject.to_s).to eq("Building #42 (unavailable)")
  end

  it "returns id" do
    expect(subject.id).to eq(42)
  end

  it "returns to_param" do
    expect(subject.to_param).to eq("42")
  end

  it "reports as persisted" do
    expect(subject.persisted?).to be true
  end

  it "reports as error" do
    expect(subject.error?).to be true
  end

  it "responds to any method via method_missing" do
    expect(subject.name).to be_nil
    expect(subject.address).to be_nil
    expect(subject.some_random_field).to be_nil
  end

  it "reports respond_to_missing? as true" do
    expect(subject.respond_to?(:anything)).to be true
  end
end
