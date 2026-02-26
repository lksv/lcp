require "spec_helper"

RSpec.describe LcpRuby::Groups::YamlLoader do
  let(:fixtures_path) { File.expand_path("../../../fixtures/metadata", __dir__) }
  let(:loader) { described_class.new }

  before do
    loader.load(fixtures_path)
  end

  describe "#all_group_names" do
    it "returns sorted group names from the YAML file" do
      expect(loader.all_group_names).to eq(%w[it_admins sales_team])
    end
  end

  describe "#groups_for_user" do
    it "returns groups the user belongs to via group_method" do
      user = double("User", lcp_groups: %w[sales_team])
      expect(loader.groups_for_user(user)).to eq(%w[sales_team])
    end

    it "filters out unknown groups" do
      user = double("User", lcp_groups: %w[sales_team nonexistent])
      expect(loader.groups_for_user(user)).to eq(%w[sales_team])
    end

    it "returns empty array when user is nil" do
      expect(loader.groups_for_user(nil)).to eq([])
    end

    it "returns empty array when user does not respond to group_method" do
      user = double("User")
      expect(loader.groups_for_user(user)).to eq([])
    end

    it "works with custom group_method" do
      LcpRuby.configuration.group_method = :custom_groups
      user = double("User", custom_groups: %w[it_admins])

      expect(loader.groups_for_user(user)).to eq(%w[it_admins])
    ensure
      LcpRuby.configuration.group_method = :lcp_groups
    end
  end

  describe "#roles_for_group" do
    it "returns roles for a known group" do
      expect(loader.roles_for_group("sales_team")).to eq(%w[sales_rep viewer])
    end

    it "returns roles for another group" do
      expect(loader.roles_for_group("it_admins")).to eq(%w[admin])
    end

    it "returns empty array for unknown group" do
      expect(loader.roles_for_group("nonexistent")).to eq([])
    end
  end

  describe "#roles_for_user" do
    it "composes groups and role mappings" do
      user = double("User", lcp_groups: %w[sales_team it_admins])
      expect(loader.roles_for_user(user)).to match_array(%w[sales_rep viewer admin])
    end

    it "deduplicates roles" do
      user = double("User", lcp_groups: %w[sales_team])
      expect(loader.roles_for_user(user)).to eq(%w[sales_rep viewer])
    end
  end

  describe "#load" do
    it "handles missing groups file gracefully and logs warning" do
      empty_loader = described_class.new

      expect(Rails.logger).to receive(:warn).with(/No groups\.yml/)
      empty_loader.load("/nonexistent/path")

      expect(empty_loader.all_group_names).to eq([])
    end

    it "handles empty YAML file and logs warning" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "groups.yml"), "")
        empty_loader = described_class.new

        expect(Rails.logger).to receive(:warn).with(/is empty/)
        empty_loader.load(dir)

        expect(empty_loader.all_group_names).to eq([])
      end
    end

    it "handles YAML without groups key and logs warning" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "groups.yml"), "other_key: value")
        bad_loader = described_class.new

        expect(Rails.logger).to receive(:warn).with(/missing 'groups' array key/)
        bad_loader.load(dir)

        expect(bad_loader.all_group_names).to eq([])
      end
    end

    it "handles YAML with non-array groups key and logs warning" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "groups.yml"), "groups: not_an_array")
        bad_loader = described_class.new

        expect(Rails.logger).to receive(:warn).with(/missing 'groups' array key/)
        bad_loader.load(dir)

        expect(bad_loader.all_group_names).to eq([])
      end
    end

    it "raises MetadataError for YAML syntax errors" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "groups.yml"), "groups:\n  - name: bad\n  invalid: yaml: content:")
        bad_loader = described_class.new
        expect {
          bad_loader.load(dir)
        }.to raise_error(LcpRuby::MetadataError, /YAML syntax error/)
      end
    end
  end

  describe "#groups_for_user logging" do
    it "logs warning when user has groups not defined in YAML" do
      user = double("User", lcp_groups: %w[sales_team nonexistent_group])

      expect(Rails.logger).to receive(:warn).with(/User has groups not defined in YAML: nonexistent_group/)
      result = loader.groups_for_user(user)

      expect(result).to eq(%w[sales_team])
    end

    it "does not log when all user groups are defined" do
      user = double("User", lcp_groups: %w[sales_team])

      expect(Rails.logger).not_to receive(:warn)
      loader.groups_for_user(user)
    end
  end
end
