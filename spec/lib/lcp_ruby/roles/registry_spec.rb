require "spec_helper"
require "support/integration_helper"

RSpec.describe LcpRuby::Roles::Registry do
  before(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("role_source_test")
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("role_source_test")
  end

  before(:each) do
    Object.new.extend(IntegrationHelper).load_integration_metadata!("role_source_test")
    # Configure role_source after metadata load (reset! clears config)
    LcpRuby.configuration.role_source = :model
    described_class.mark_available!
  end

  let(:role_model) { LcpRuby.registry.model_for("role") }

  describe ".all_role_names" do
    it "returns empty array when no roles exist" do
      expect(described_class.all_role_names).to eq([])
    end

    it "returns sorted role names" do
      role_model.create!(name: "viewer", label: "Viewer")
      role_model.create!(name: "admin", label: "Admin")

      described_class.reload!
      expect(described_class.all_role_names).to eq(%w[admin viewer])
    end

    it "only returns active roles" do
      role_model.create!(name: "admin", label: "Admin", active: true)
      role_model.create!(name: "deprecated", label: "Deprecated", active: false)

      described_class.reload!
      result = described_class.all_role_names
      expect(result).to include("admin")
      expect(result).not_to include("deprecated")
    end

    it "caches results" do
      role_model.create!(name: "cached", label: "Cached")

      described_class.reload!
      result1 = described_class.all_role_names
      result2 = described_class.all_role_names
      expect(result1).to equal(result2)
    end
  end

  describe ".valid_role?" do
    it "returns true for existing role" do
      role_model.create!(name: "admin", label: "Admin")
      described_class.reload!

      expect(described_class.valid_role?("admin")).to be true
    end

    it "returns false for non-existing role" do
      expect(described_class.valid_role?("nonexistent")).to be false
    end
  end

  describe ".reload!" do
    it "clears cache so next access re-queries DB" do
      role_model.create!(name: "before_reload", label: "Before")
      described_class.reload!
      result1 = described_class.all_role_names

      described_class.reload!

      role_model.create!(name: "after_reload", label: "After")
      described_class.reload!
      result2 = described_class.all_role_names

      expect(result1).not_to equal(result2)
      expect(result2).to include("after_reload")
    end
  end

  describe ".available?" do
    it "returns true after mark_available!" do
      described_class.clear!
      expect(described_class.available?).to be false

      described_class.mark_available!
      expect(described_class.available?).to be true
    end
  end

  describe ".clear!" do
    it "resets availability and cache" do
      described_class.mark_available!
      described_class.clear!
      expect(described_class.available?).to be false
    end

    it "returns empty array when not available" do
      described_class.clear!
      expect(described_class.all_role_names).to eq([])
    end
  end
end
