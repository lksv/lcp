require "spec_helper"

RSpec.describe LcpRuby::Auditing::Registry do
  before { described_class.clear! }

  describe ".available?" do
    it "returns false by default" do
      expect(described_class.available?).to be false
    end

    it "returns true after mark_available!" do
      described_class.mark_available!
      expect(described_class.available?).to be true
    end

    it "returns false after clear!" do
      described_class.mark_available!
      described_class.clear!
      expect(described_class.available?).to be false
    end
  end

  describe ".audit_model_class" do
    it "returns nil when not available" do
      expect(described_class.audit_model_class).to be_nil
    end
  end
end
