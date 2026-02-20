require "spec_helper"

RSpec.describe LcpRuby::User, type: :model do
  before(:all) do
    # Create the users table for tests
    ActiveRecord::Schema.define do
      create_table :lcp_ruby_users, force: true do |t|
        t.string :name,               null: false
        t.json   :lcp_role,           default: ["viewer"]
        t.boolean :active,            null: false, default: true
        t.json   :profile_data,       default: {}
        t.string :email,              null: false, default: ""
        t.string :encrypted_password, null: false, default: ""
        t.string   :reset_password_token
        t.datetime :reset_password_sent_at
        t.datetime :remember_created_at
        t.integer  :sign_in_count, default: 0, null: false
        t.datetime :current_sign_in_at
        t.datetime :last_sign_in_at
        t.string   :current_sign_in_ip
        t.string   :last_sign_in_ip
        t.integer  :failed_attempts, default: 0, null: false
        t.string   :unlock_token
        t.datetime :locked_at
        t.timestamps null: false
      end

      add_index :lcp_ruby_users, :email,                unique: true
      add_index :lcp_ruby_users, :reset_password_token, unique: true
      add_index :lcp_ruby_users, :unlock_token,         unique: true
    end

    # Set up Devise for tests
    LcpRuby.configuration.authentication = :built_in
    LcpRuby::Authentication.setup_devise!
  end

  after(:all) do
    ActiveRecord::Base.connection.drop_table(:lcp_ruby_users, if_exists: true)
  end

  before(:each) do
    LcpRuby.configuration.authentication = :built_in
    LcpRuby::User.delete_all
  end

  def build_user(overrides = {})
    LcpRuby::User.new({
      name: "Test User",
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    }.merge(overrides))
  end

  describe "validations" do
    it "is valid with valid attributes" do
      user = build_user
      expect(user).to be_valid
    end

    it "requires name" do
      user = build_user(name: nil)
      expect(user).not_to be_valid
      expect(user.errors[:name]).to include("can't be blank")
    end

    it "requires email" do
      user = build_user(email: nil)
      expect(user).not_to be_valid
    end

    it "requires unique email" do
      build_user.save!
      duplicate = build_user(name: "Other User")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:email]).to include("has already been taken")
    end

    it "requires password" do
      user = build_user(password: nil, password_confirmation: nil)
      expect(user).not_to be_valid
    end

    it "enforces minimum password length" do
      user = build_user(password: "short", password_confirmation: "short")
      expect(user).not_to be_valid
      expect(user.errors[:password]).to be_present
    end
  end

  describe "#lcp_role" do
    it "returns an array" do
      user = build_user
      user.save!
      expect(user.lcp_role).to be_an(Array)
    end

    it "returns default role for new users" do
      user = build_user
      user.save!
      user.reload
      expect(user.lcp_role).to eq(["viewer"])
    end

    it "stores multiple roles" do
      user = build_user
      user.lcp_role = ["admin", "editor"]
      user.save!
      user.reload
      expect(user.lcp_role).to eq(["admin", "editor"])
    end

    it "wraps single role in array" do
      user = build_user
      user.write_attribute(:lcp_role, "admin")
      expect(user.lcp_role).to eq(["admin"])
    end
  end

  describe "#profile" do
    it "returns empty hash by default" do
      user = build_user
      expect(user.profile).to eq({})
    end

    it "returns profile_data with indifferent access" do
      user = build_user
      user.profile_data = { "department" => "Engineering", "phone" => "+1234" }
      expect(user.profile[:department]).to eq("Engineering")
      expect(user.profile["department"]).to eq("Engineering")
    end
  end

  describe "scopes" do
    it ".active returns only active users" do
      active = build_user(email: "active@test.com")
      active.save!

      inactive = build_user(email: "inactive@test.com", active: false)
      inactive.save!

      expect(LcpRuby::User.active).to include(active)
      expect(LcpRuby::User.active).not_to include(inactive)
    end
  end
end
