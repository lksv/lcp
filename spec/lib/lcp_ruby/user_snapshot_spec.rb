require "spec_helper"

RSpec.describe LcpRuby::UserSnapshot do
  describe ".capture" do
    it "returns nil for nil user" do
      expect(described_class.capture(nil)).to be_nil
    end

    it "captures id, email, name, and role from a full user" do
      user_class = Struct.new(:id, :email, :name, :lcp_role)
      user = user_class.new(42, "alice@example.com", "Alice", "admin")

      snapshot = described_class.capture(user)

      expect(snapshot).to eq({
        "id" => 42,
        "email" => "alice@example.com",
        "name" => "Alice",
        "role" => "admin"
      })
    end

    it "omits email when user does not respond to it" do
      user_class = Struct.new(:id, :name, :lcp_role)
      user = user_class.new(1, "Bob", "viewer")

      snapshot = described_class.capture(user)

      expect(snapshot).not_to have_key("email")
      expect(snapshot["name"]).to eq("Bob")
      expect(snapshot["role"]).to eq("viewer")
    end

    it "omits name when user does not respond to it" do
      user_class = Struct.new(:id, :email, :lcp_role)
      user = user_class.new(1, "bob@example.com", "viewer")

      snapshot = described_class.capture(user)

      expect(snapshot).not_to have_key("name")
      expect(snapshot["email"]).to eq("bob@example.com")
    end

    it "omits role when user does not respond to role_method" do
      user_class = Struct.new(:id)
      user = user_class.new(1)

      snapshot = described_class.capture(user)

      expect(snapshot).to eq({ "id" => 1 })
    end
  end
end
