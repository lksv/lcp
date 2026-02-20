require "spec_helper"

RSpec.describe LcpRuby::Services::Accessors::JsonField do
  let(:record) { double("record") }

  describe ".get" do
    it "reads value from JSON column" do
      allow(record).to receive(:metadata).and_return({ "color" => "red" })
      value = described_class.get(record, options: { "column" => "metadata", "key" => "color" })
      expect(value).to eq("red")
    end

    it "returns nil when column is nil" do
      allow(record).to receive(:metadata).and_return(nil)
      value = described_class.get(record, options: { "column" => "metadata", "key" => "color" })
      expect(value).to be_nil
    end

    it "returns nil when key is missing" do
      allow(record).to receive(:metadata).and_return({ "other" => "value" })
      value = described_class.get(record, options: { "column" => "metadata", "key" => "color" })
      expect(value).to be_nil
    end
  end

  describe ".set" do
    before do
      allow(record).to receive(:metadata_changed?).and_return(false)
      allow(record).to receive(:metadata_will_change!)
    end

    it "writes value to JSON column" do
      allow(record).to receive(:metadata).and_return({ "existing" => "data" })
      expect(record).to receive(:metadata=).with({ "existing" => "data", "color" => "blue" })
      described_class.set(record, "blue", options: { "column" => "metadata", "key" => "color" })
    end

    it "initializes JSON column when nil" do
      allow(record).to receive(:metadata).and_return(nil)
      expect(record).to receive(:metadata=).with({ "color" => "blue" })
      described_class.set(record, "blue", options: { "column" => "metadata", "key" => "color" })
    end

    it "overwrites existing key value" do
      allow(record).to receive(:metadata).and_return({ "color" => "red" })
      expect(record).to receive(:metadata=).with({ "color" => "green" })
      described_class.set(record, "green", options: { "column" => "metadata", "key" => "color" })
    end

    it "marks column dirty before assignment" do
      allow(record).to receive(:metadata).and_return({ "color" => "red" })
      allow(record).to receive(:metadata=)
      expect(record).to receive(:metadata_will_change!)
      described_class.set(record, "red", options: { "column" => "metadata", "key" => "color" })
    end

    it "skips will_change! when column is already dirty" do
      allow(record).to receive(:metadata_changed?).and_return(true)
      allow(record).to receive(:metadata).and_return({})
      allow(record).to receive(:metadata=)
      expect(record).not_to receive(:metadata_will_change!)
      described_class.set(record, "blue", options: { "column" => "metadata", "key" => "color" })
    end
  end
end
