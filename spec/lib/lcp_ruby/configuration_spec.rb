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
end
