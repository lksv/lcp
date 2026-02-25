require "spec_helper"

RSpec.describe LcpRuby::Groups::Registry do
  let(:mock_loader) do
    loader = double("GroupLoader")
    allow(loader).to receive(:all_group_names).and_return(%w[admins editors])
    allow(loader).to receive(:groups_for_user).and_return(%w[editors])
    allow(loader).to receive(:roles_for_group).with("editors").and_return(%w[editor])
    allow(loader).to receive(:roles_for_user).and_return(%w[editor])
    loader
  end

  before(:each) do
    described_class.clear!
  end

  describe ".available?" do
    it "returns false by default" do
      expect(described_class.available?).to be false
    end

    it "returns true after mark_available!" do
      described_class.mark_available!
      expect(described_class.available?).to be true
    end
  end

  describe ".all_group_names" do
    it "returns empty array when not available" do
      expect(described_class.all_group_names).to eq([])
    end

    it "delegates to loader when available" do
      described_class.set_loader(mock_loader)
      described_class.mark_available!

      expect(described_class.all_group_names).to eq(%w[admins editors])
    end

    it "caches results" do
      described_class.set_loader(mock_loader)
      described_class.mark_available!

      result1 = described_class.all_group_names
      result2 = described_class.all_group_names
      expect(result1).to equal(result2)
      expect(mock_loader).to have_received(:all_group_names).once
    end
  end

  describe ".groups_for_user" do
    it "returns empty array when not available" do
      expect(described_class.groups_for_user(double)).to eq([])
    end

    it "delegates to loader when available" do
      user = double("User")
      described_class.set_loader(mock_loader)
      described_class.mark_available!

      expect(described_class.groups_for_user(user)).to eq(%w[editors])
    end
  end

  describe ".roles_for_group" do
    it "returns empty array when not available" do
      expect(described_class.roles_for_group("editors")).to eq([])
    end

    it "delegates to loader when available" do
      described_class.set_loader(mock_loader)
      described_class.mark_available!

      expect(described_class.roles_for_group("editors")).to eq(%w[editor])
    end
  end

  describe ".roles_for_user" do
    it "returns empty array when not available" do
      expect(described_class.roles_for_user(double)).to eq([])
    end

    it "delegates to loader when available" do
      user = double("User")
      described_class.set_loader(mock_loader)
      described_class.mark_available!

      expect(described_class.roles_for_user(user)).to eq(%w[editor])
    end
  end

  describe ".reload!" do
    it "clears the cache" do
      described_class.set_loader(mock_loader)
      described_class.mark_available!

      described_class.all_group_names
      described_class.reload!
      described_class.all_group_names

      expect(mock_loader).to have_received(:all_group_names).twice
    end
  end

  describe ".clear!" do
    it "resets availability and cache" do
      described_class.set_loader(mock_loader)
      described_class.mark_available!
      described_class.clear!

      expect(described_class.available?).to be false
      expect(described_class.all_group_names).to eq([])
    end
  end

  describe "thread safety" do
    it "handles concurrent reads without errors" do
      described_class.set_loader(mock_loader)
      described_class.mark_available!

      errors = []
      threads = 10.times.map do
        Thread.new do
          50.times do
            result = described_class.all_group_names
            errors << "unexpected result" unless result == %w[admins editors]
          end
        rescue => e
          errors << e.message
        end
      end
      threads.each(&:join)

      expect(errors).to be_empty
    end

    it "handles concurrent reload! and reads without errors" do
      described_class.set_loader(mock_loader)
      described_class.mark_available!

      errors = []
      threads = []

      # Reader threads
      5.times do
        threads << Thread.new do
          30.times do
            result = described_class.all_group_names
            errors << "unexpected result: #{result}" unless result == %w[admins editors]
          end
        rescue => e
          errors << e.message
        end
      end

      # Writer threads (reload! clears cache)
      5.times do
        threads << Thread.new do
          30.times { described_class.reload! }
        rescue => e
          errors << e.message
        end
      end

      threads.each(&:join)
      expect(errors).to be_empty
    end
  end

  describe "cache invalidation actually clears data" do
    it "returns fresh data after reload!" do
      # First loader returns one set
      loader1 = double("Loader1")
      allow(loader1).to receive(:all_group_names).and_return(%w[group_a], %w[group_a group_b])

      described_class.set_loader(loader1)
      described_class.mark_available!

      # Cache the first result
      expect(described_class.all_group_names).to eq(%w[group_a])

      # Reload clears cache, next call returns fresh data
      described_class.reload!
      expect(described_class.all_group_names).to eq(%w[group_a group_b])
    end
  end
end
