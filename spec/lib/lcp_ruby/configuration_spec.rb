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
end
