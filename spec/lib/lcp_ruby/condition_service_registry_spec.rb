require "spec_helper"

RSpec.describe LcpRuby::ConditionServiceRegistry do
  before { described_class.clear! }

  describe ".register / .lookup" do
    it "registers and looks up a service" do
      service = Class.new { def self.call(record) = true }
      described_class.register("test_service", service)

      expect(described_class.lookup("test_service")).to eq(service)
    end

    it "returns nil for unregistered keys" do
      expect(described_class.lookup("nonexistent")).to be_nil
    end

    it "handles symbol keys" do
      service = Class.new { def self.call(record) = true }
      described_class.register(:test_service, service)

      expect(described_class.lookup("test_service")).to eq(service)
      expect(described_class.lookup(:test_service)).to eq(service)
    end
  end

  describe ".registered?" do
    it "returns true for registered services" do
      service = Class.new { def self.call(record) = true }
      described_class.register("test_service", service)

      expect(described_class.registered?("test_service")).to be true
    end

    it "returns false for unregistered services" do
      expect(described_class.registered?("nonexistent")).to be false
    end
  end

  describe ".clear!" do
    it "removes all registered services" do
      service = Class.new { def self.call(record) = true }
      described_class.register("test_service", service)

      described_class.clear!

      expect(described_class.registered?("test_service")).to be false
    end
  end

  describe ".discover!" do
    it "discovers services from a directory" do
      fixture_path = File.expand_path("../../fixtures/integration/todo", __dir__)
      described_class.discover!(fixture_path)

      expect(described_class.registered?("persisted_check")).to be true
    end

    it "does nothing for non-existent directory" do
      described_class.discover!("/nonexistent/path")

      # No error raised
      expect(described_class.registered?("anything")).to be false
    end
  end
end
