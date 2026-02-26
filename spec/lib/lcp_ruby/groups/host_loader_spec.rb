require "spec_helper"

RSpec.describe LcpRuby::Groups::HostLoader do
  let(:adapter) do
    double("Adapter",
      all_group_names: %w[team_a team_b],
      groups_for_user: %w[team_a],
      roles_for_group: %w[admin]
    )
  end

  let(:loader) { described_class.new(adapter) }

  describe "#all_group_names" do
    it "delegates to adapter" do
      expect(loader.all_group_names).to eq(%w[team_a team_b])
    end
  end

  describe "#groups_for_user" do
    it "delegates to adapter" do
      user = double("User")
      expect(loader.groups_for_user(user)).to eq(%w[team_a])
    end
  end

  describe "#roles_for_group" do
    it "delegates to adapter" do
      expect(loader.roles_for_group("team_a")).to eq(%w[admin])
    end
  end

  describe "#roles_for_user" do
    context "when adapter provides roles_for_user" do
      it "delegates to adapter's optimized implementation" do
        allow(adapter).to receive(:roles_for_user).and_return(%w[admin editor])
        expect(loader.roles_for_user(double("User"))).to eq(%w[admin editor])
      end
    end

    context "when adapter does not provide roles_for_user" do
      it "falls back to default composition" do
        adapter_without = double("BasicAdapter",
          all_group_names: %w[team_a],
          groups_for_user: %w[team_a],
          roles_for_group: %w[admin]
        )

        basic_loader = described_class.new(adapter_without)
        user = double("User")

        expect(basic_loader.roles_for_user(user)).to eq(%w[admin])
      end
    end
  end
end
