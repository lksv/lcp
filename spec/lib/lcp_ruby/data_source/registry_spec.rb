require "spec_helper"

RSpec.describe LcpRuby::DataSource::Registry do
  after { described_class.clear! }

  describe ".available?" do
    it "defaults to false" do
      expect(described_class.available?).to be false
    end

    it "returns true after mark_available!" do
      described_class.mark_available!
      expect(described_class.available?).to be true
    end
  end

  describe ".register / .adapter_for" do
    it "stores and retrieves adapters" do
      adapter = double("adapter")
      described_class.register("my_model", adapter)

      expect(described_class.adapter_for("my_model")).to eq(adapter)
    end

    it "returns nil for unregistered models" do
      expect(described_class.adapter_for("unknown")).to be_nil
    end
  end

  describe ".registered?" do
    it "returns true when registered" do
      described_class.register("my_model", double)
      expect(described_class.registered?("my_model")).to be true
    end

    it "returns false when not registered" do
      expect(described_class.registered?("unknown")).to be false
    end
  end

  describe ".clear!" do
    it "resets all state" do
      described_class.mark_available!
      described_class.register("my_model", double)

      described_class.clear!

      expect(described_class.available?).to be false
      expect(described_class.adapter_for("my_model")).to be_nil
    end
  end
end
