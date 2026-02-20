require "spec_helper"

RSpec.describe LcpRuby::Authentication do
  describe ".built_in?" do
    it "returns true when authentication is :built_in" do
      LcpRuby.configuration.authentication = :built_in
      expect(described_class.built_in?).to be true
    end

    it "returns false when authentication is :external" do
      LcpRuby.configuration.authentication = :external
      expect(described_class.built_in?).to be false
    end
  end

  describe ".none?" do
    it "returns true when authentication is :none" do
      LcpRuby.configuration.authentication = :none
      expect(described_class.none?).to be true
    end

    it "returns false when authentication is :built_in" do
      LcpRuby.configuration.authentication = :built_in
      expect(described_class.none?).to be false
    end
  end

  describe ".external?" do
    it "returns true when authentication is :external" do
      LcpRuby.configuration.authentication = :external
      expect(described_class.external?).to be true
    end

    it "returns false when authentication is :none" do
      LcpRuby.configuration.authentication = :none
      expect(described_class.external?).to be false
    end
  end
end

RSpec.describe LcpRuby::Configuration do
  describe "authentication attributes" do
    it "defaults to :external" do
      config = LcpRuby::Configuration.new
      expect(config.authentication).to eq(:external)
    end

    it "accepts :none" do
      config = LcpRuby::Configuration.new
      config.authentication = :none
      expect(config.authentication).to eq(:none)
    end

    it "accepts :built_in" do
      config = LcpRuby::Configuration.new
      config.authentication = :built_in
      expect(config.authentication).to eq(:built_in)
    end

    it "accepts string values and converts to symbol" do
      config = LcpRuby::Configuration.new
      config.authentication = "built_in"
      expect(config.authentication).to eq(:built_in)
    end

    it "rejects invalid values" do
      config = LcpRuby::Configuration.new
      expect { config.authentication = :invalid }.to raise_error(ArgumentError, /must be :none, :built_in, or :external/)
    end

    it "defaults auth_allow_registration to false" do
      config = LcpRuby::Configuration.new
      expect(config.auth_allow_registration).to be false
    end

    it "defaults auth_password_min_length to 8" do
      config = LcpRuby::Configuration.new
      expect(config.auth_password_min_length).to eq(8)
    end

    it "defaults auth_mailer_sender" do
      config = LcpRuby::Configuration.new
      expect(config.auth_mailer_sender).to eq("noreply@example.com")
    end

    it "defaults auth_after_login_path to /" do
      config = LcpRuby::Configuration.new
      expect(config.auth_after_login_path).to eq("/")
    end

    it "defaults auth_lock_after_attempts to 0 (disabled)" do
      config = LcpRuby::Configuration.new
      expect(config.auth_lock_after_attempts).to eq(0)
    end
  end
end
