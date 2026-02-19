require "spec_helper"

RSpec.describe LcpRuby::ImpersonatedUser do
  let(:real_user) { OpenStruct.new(id: 42, name: "Real Admin", lcp_role: [ "admin" ]) }
  let(:impersonated_role) { "viewer" }
  subject(:impersonated) { described_class.new(real_user, impersonated_role) }

  describe "#method_missing" do
    context "with default role_method (:lcp_role)" do
      it "returns impersonated role as array" do
        expect(impersonated.lcp_role).to eq([ "viewer" ])
      end

      it "does not return the real user's role" do
        expect(impersonated.lcp_role).not_to include("admin")
      end
    end

    context "with custom role_method" do
      before { LcpRuby.configuration.role_method = :custom_role }
      after { LcpRuby.configuration.role_method = :lcp_role }

      let(:real_user) { OpenStruct.new(id: 42, custom_role: [ "admin" ], name: "Admin") }

      it "overrides the configured role_method" do
        expect(impersonated.custom_role).to eq([ "viewer" ])
      end

      it "still delegates lcp_role to the real user" do
        real_user.lcp_role = [ "admin" ]
        expect(impersonated.lcp_role).to eq([ "admin" ])
      end
    end
  end

  describe "delegation to real user" do
    it "delegates id to the real user" do
      expect(impersonated.id).to eq(42)
    end

    it "delegates name to the real user" do
      expect(impersonated.name).to eq("Real Admin")
    end
  end

  describe "#respond_to_missing?" do
    it "responds to the configured role_method" do
      expect(impersonated.respond_to?(:lcp_role)).to be true
    end

    it "responds to methods on the real user" do
      expect(impersonated.respond_to?(:name)).to be true
    end

    it "does not respond to unknown methods" do
      expect(impersonated.respond_to?(:nonexistent_method)).to be false
    end
  end
end
