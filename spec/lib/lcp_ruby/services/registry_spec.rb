require "spec_helper"

RSpec.describe LcpRuby::Services::Registry do
  after { described_class.clear! }

  describe ".register and .lookup" do
    it "stores and retrieves a service by category and key" do
      service = -> { "hello" }
      described_class.register("transforms", "my_transform", service)
      expect(described_class.lookup("transforms", "my_transform")).to eq(service)
    end

    it "returns nil for unregistered key" do
      expect(described_class.lookup("transforms", "nonexistent")).to be_nil
    end
  end

  describe ".registered?" do
    it "returns true for registered key" do
      described_class.register("validators", "my_validator", Object.new)
      expect(described_class.registered?("validators", "my_validator")).to be true
    end

    it "returns false for unregistered key" do
      expect(described_class.registered?("validators", "nonexistent")).to be false
    end
  end

  describe "category validation" do
    it "raises ArgumentError for unknown category" do
      expect { described_class.register("bogus", "key", Object.new) }
        .to raise_error(ArgumentError, /Invalid service category 'bogus'/)
    end

    it "accepts all valid categories" do
      %w[transforms validators conditions defaults computed].each do |cat|
        expect { described_class.register(cat, "test", Object.new) }.not_to raise_error
      end
    end
  end

  describe ".clear!" do
    it "removes all registered services" do
      described_class.register("transforms", "a", Object.new)
      described_class.register("validators", "b", Object.new)
      described_class.clear!
      expect(described_class.lookup("transforms", "a")).to be_nil
      expect(described_class.lookup("validators", "b")).to be_nil
    end
  end

  describe ".discover!" do
    let(:fixture_path) { File.expand_path("../../../fixtures/services", __dir__) }

    it "registers discovered transform services" do
      described_class.discover!(fixture_path)
      expect(described_class.registered?("transforms", "upcase")).to be true
    end

    it "registers discovered validator services" do
      described_class.discover!(fixture_path)
      expect(described_class.registered?("validators", "always_fail")).to be true
    end

    it "registers transforms as instances (not classes)" do
      described_class.discover!(fixture_path)
      service = described_class.lookup("transforms", "upcase")

      expect(service).to be_an_instance_of(LcpRuby::HostServices::Transforms::Upcase)
      expect(service).to respond_to(:call)
      expect(service.call("hello")).to eq("HELLO")
    end

    it "registers validators as classes (not instances)" do
      described_class.discover!(fixture_path)
      service = described_class.lookup("validators", "always_fail")

      expect(service).to eq(LcpRuby::HostServices::Validators::AlwaysFail)
      expect(service).to respond_to(:call)
    end

    it "does not raise when path does not exist" do
      expect { described_class.discover!("/nonexistent/path") }.not_to raise_error
    end
  end
end
