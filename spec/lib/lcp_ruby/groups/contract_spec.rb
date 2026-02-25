require "spec_helper"

RSpec.describe LcpRuby::Groups::Contract do
  let(:dummy_class) do
    Class.new do
      include LcpRuby::Groups::Contract
    end
  end

  let(:instance) { dummy_class.new }

  describe "#all_group_names" do
    it "raises NotImplementedError" do
      expect { instance.all_group_names }.to raise_error(NotImplementedError, /all_group_names/)
    end
  end

  describe "#groups_for_user" do
    it "raises NotImplementedError" do
      expect { instance.groups_for_user(double) }.to raise_error(NotImplementedError, /groups_for_user/)
    end
  end

  describe "#roles_for_group" do
    it "raises NotImplementedError" do
      expect { instance.roles_for_group("test") }.to raise_error(NotImplementedError, /roles_for_group/)
    end
  end

  describe "#roles_for_user" do
    it "composes groups_for_user and roles_for_group by default" do
      user = double("User")
      allow(instance).to receive(:groups_for_user).with(user).and_return(%w[sales_team it_admins])
      allow(instance).to receive(:roles_for_group).with("sales_team").and_return(%w[sales_rep viewer])
      allow(instance).to receive(:roles_for_group).with("it_admins").and_return(%w[admin])

      expect(instance.roles_for_user(user)).to match_array(%w[sales_rep viewer admin])
    end

    it "deduplicates roles" do
      user = double("User")
      allow(instance).to receive(:groups_for_user).with(user).and_return(%w[group_a group_b])
      allow(instance).to receive(:roles_for_group).with("group_a").and_return(%w[viewer])
      allow(instance).to receive(:roles_for_group).with("group_b").and_return(%w[viewer editor])

      expect(instance.roles_for_user(user)).to match_array(%w[viewer editor])
    end
  end
end
