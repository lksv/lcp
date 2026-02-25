require "spec_helper"

RSpec.describe LcpRuby::Configuration do
  subject(:config) { described_class.new }

  describe "#parent_controller" do
    it "defaults to ::ApplicationController" do
      expect(config.parent_controller).to eq("::ApplicationController")
    end

    it "is configurable" do
      config.parent_controller = "Admin::BaseController"
      expect(config.parent_controller).to eq("Admin::BaseController")
    end
  end

  describe "#role_method" do
    it "defaults to :lcp_role" do
      expect(config.role_method).to eq(:lcp_role)
    end
  end

  describe "#auto_migrate" do
    it "defaults to true" do
      expect(config.auto_migrate).to be true
    end
  end

  describe "#impersonation_roles" do
    it "defaults to empty array" do
      expect(config.impersonation_roles).to eq([])
    end

    it "is configurable" do
      config.impersonation_roles = [ "admin", "super_admin" ]
      expect(config.impersonation_roles).to eq([ "admin", "super_admin" ])
    end
  end

  describe "#strict_loading" do
    it "defaults to :never" do
      expect(config.strict_loading).to eq(:never)
    end

    it "is configurable" do
      config.strict_loading = :always
      expect(config.strict_loading).to eq(:always)
    end
  end

  describe "#strict_loading_enabled?" do
    it "returns false for :never" do
      config.strict_loading = :never
      expect(config.strict_loading_enabled?).to be false
    end

    it "returns true for :always" do
      config.strict_loading = :always
      expect(config.strict_loading_enabled?).to be true
    end

    it "returns true for :development in test environment" do
      config.strict_loading = :development
      # RSpec runs in test environment
      expect(config.strict_loading_enabled?).to be true
    end

    it "returns false for unknown values" do
      config.strict_loading = :something_else
      expect(config.strict_loading_enabled?).to be false
    end
  end

  describe "#group_source=" do
    it "accepts valid values" do
      %i[none yaml model host].each do |value|
        config.group_source = value
        expect(config.group_source).to eq(value)
      end
    end

    it "coerces strings to symbols" do
      config.group_source = "yaml"
      expect(config.group_source).to eq(:yaml)
    end

    it "raises ArgumentError for invalid values" do
      expect {
        config.group_source = :invalid
      }.to raise_error(ArgumentError, /group_source must be/)
    end
  end

  describe "#role_resolution_strategy=" do
    it "accepts valid values" do
      %i[merged groups_only direct_only].each do |value|
        config.role_resolution_strategy = value
        expect(config.role_resolution_strategy).to eq(value)
      end
    end

    it "coerces strings to symbols" do
      config.role_resolution_strategy = "groups_only"
      expect(config.role_resolution_strategy).to eq(:groups_only)
    end

    it "raises ArgumentError for invalid values" do
      expect {
        config.role_resolution_strategy = :invalid
      }.to raise_error(ArgumentError, /role_resolution_strategy must be/)
    end
  end

  describe "group defaults" do
    it "defaults group_source to :none" do
      expect(config.group_source).to eq(:none)
    end

    it "defaults group_method to :lcp_groups" do
      expect(config.group_method).to eq(:lcp_groups)
    end

    it "defaults group_role_mapping_model to nil" do
      expect(config.group_role_mapping_model).to be_nil
    end

    it "defaults role_resolution_strategy to :merged" do
      expect(config.role_resolution_strategy).to eq(:merged)
    end
  end

  describe ".json_column_type" do
    it "returns :json for SQLite adapter" do
      expect(LcpRuby.json_column_type).to eq(:json)
    end
  end
end
