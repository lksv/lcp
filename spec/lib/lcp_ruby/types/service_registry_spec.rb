require "spec_helper"

RSpec.describe LcpRuby::Types::ServiceRegistry do
  after { described_class.clear! }

  describe ".register and .lookup" do
    it "registers and retrieves a service by category and key" do
      service = double("transform")
      described_class.register("transform", "strip", service)

      expect(described_class.lookup("transform", "strip")).to eq(service)
    end

    it "returns nil for unregistered key" do
      expect(described_class.lookup("transform", "nonexistent")).to be_nil
    end
  end

  describe ".registered?" do
    it "returns true for a registered service" do
      described_class.register("transform", "strip", double)
      expect(described_class.registered?("transform", "strip")).to be true
    end

    it "returns false for an unregistered service" do
      expect(described_class.registered?("transform", "strip")).to be false
    end
  end

  describe "category isolation" do
    it "keeps services separate across categories" do
      transform = double("transform")
      validator = double("validator")

      described_class.register("transform", "strip", transform)
      described_class.register("validator", "strip", validator)

      expect(described_class.lookup("transform", "strip")).to eq(transform)
      expect(described_class.lookup("validator", "strip")).to eq(validator)
    end
  end

  describe "category validation" do
    it "raises ArgumentError for invalid category on register" do
      expect {
        described_class.register("invalid_category", "key", double)
      }.to raise_error(ArgumentError, /Invalid service category/)
    end

    it "raises ArgumentError for invalid category on lookup" do
      expect {
        described_class.lookup("invalid_category", "key")
      }.to raise_error(ArgumentError, /Invalid service category/)
    end

    it "raises ArgumentError for invalid category on registered?" do
      expect {
        described_class.registered?("invalid_category", "key")
      }.to raise_error(ArgumentError, /Invalid service category/)
    end
  end

  describe ".clear!" do
    it "removes all registered services" do
      described_class.register("transform", "strip", double)
      described_class.register("validator", "email", double)

      described_class.clear!

      expect(described_class.registered?("transform", "strip")).to be false
      expect(described_class.registered?("validator", "email")).to be false
    end
  end
end
