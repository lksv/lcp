require "spec_helper"
require "ostruct"

# Stub host provider for tests
class TestHostProvider
  def find(id)
    OpenStruct.new(id: id, name: "Record #{id}")
  end

  def search(params = {}, sort: nil, page: 1, per: 25)
    LcpRuby::SearchResult.new(
      records: [ OpenStruct.new(id: 1, name: "Record 1") ],
      total_count: 1, current_page: page, per_page: per
    )
  end

  def supported_operators
    %w[eq cont]
  end
end

class TestInvalidProvider
  # Missing required #find and #search
end

RSpec.describe LcpRuby::DataSource::Host do
  let(:model_def) do
    LcpRuby::Metadata::ModelDefinition.new(
      name: "test_host_model",
      fields: [],
      data_source_config: { "type" => "host", "provider" => "TestHostProvider" }
    )
  end

  describe "initialization" do
    it "validates provider implements contract" do
      expect {
        described_class.new({ "provider" => "TestHostProvider" }, model_def)
      }.not_to raise_error
    end

    it "raises when provider class not found" do
      expect {
        described_class.new({ "provider" => "NonExistentClass" }, model_def)
      }.to raise_error(NameError)
    end

    it "raises when provider missing required methods" do
      expect {
        described_class.new({ "provider" => "TestInvalidProvider" }, model_def)
      }.to raise_error(LcpRuby::MetadataError, /must implement/)
    end

    it "raises when provider config is nil" do
      expect {
        described_class.new({}, model_def)
      }.to raise_error(LcpRuby::MetadataError, /requires 'provider'/)
    end
  end

  describe "delegation" do
    subject { described_class.new({ "provider" => "TestHostProvider" }, model_def) }

    it "delegates find" do
      record = subject.find(42)
      expect(record.id).to eq(42)
    end

    it "delegates search" do
      result = subject.search
      expect(result.total_count).to eq(1)
    end

    it "delegates supported_operators" do
      expect(subject.supported_operators).to eq(%w[eq cont])
    end
  end
end
