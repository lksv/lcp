require "spec_helper"
require "support/integration_helper"

RSpec.describe "Permission Source Integration", type: :request do
  before(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("permission_source_test")
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("permission_source_test")
  end

  before(:each) do
    load_integration_metadata!("permission_source_test")
    # Configure permission_source after metadata load (reset! clears config)
    LcpRuby.configuration.permission_source = :model
    LcpRuby::Permissions::Registry.mark_available!
    LcpRuby::Permissions::ChangeHandler.install!(perm_model)
    LcpRuby::Permissions::DefinitionValidator.install!(perm_model)
  end

  let(:perm_model) { LcpRuby.registry.model_for("permission_config") }
  let(:task_model) { LcpRuby.registry.model_for("task") }

  describe "Registry after boot" do
    it "marks the registry as available" do
      expect(LcpRuby::Permissions::Registry.available?).to be true
    end

    it "returns nil when no DB record exists" do
      expect(LcpRuby::Permissions::Registry.for_model("task")).to be_nil
    end

    it "returns a parsed PermissionDefinition when DB record exists" do
      perm_model.create!(
        target_model: "task",
        definition: {
          "roles" => {
            "db_admin" => {
              "crud" => %w[index show create update destroy],
              "fields" => { "readable" => "all", "writable" => "all" }
            }
          },
          "default_role" => "db_admin"
        }
      )
      LcpRuby::Permissions::Registry.reload!("task")

      result = LcpRuby::Permissions::Registry.for_model("task")
      expect(result).to be_a(LcpRuby::Metadata::PermissionDefinition)
      expect(result.roles).to have_key("db_admin")
    end

    it "filters by active flag" do
      perm_model.create!(
        target_model: "task",
        definition: { "roles" => { "admin" => {} }, "default_role" => "admin" },
        active: false
      )
      LcpRuby::Permissions::Registry.reload!("task")

      expect(LcpRuby::Permissions::Registry.for_model("task")).to be_nil
    end
  end

  describe "Cache invalidation" do
    it "updates cache when a permission config is created" do
      expect(LcpRuby::Permissions::Registry.for_model("task")).to be_nil

      perm_model.create!(
        target_model: "task",
        definition: { "roles" => { "admin" => {} }, "default_role" => "admin" }
      )

      # after_commit triggers reload
      result = LcpRuby::Permissions::Registry.for_model("task")
      expect(result).to be_a(LcpRuby::Metadata::PermissionDefinition)
    end

    it "updates cache when a permission config is updated" do
      record = perm_model.create!(
        target_model: "task",
        definition: { "roles" => { "old_role" => {} }, "default_role" => "old_role" }
      )

      result = LcpRuby::Permissions::Registry.for_model("task")
      expect(result.default_role).to eq("old_role")

      record.update!(
        definition: { "roles" => { "new_role" => {} }, "default_role" => "new_role" }
      )

      result = LcpRuby::Permissions::Registry.for_model("task")
      expect(result.default_role).to eq("new_role")
    end

    it "updates cache when a permission config is destroyed" do
      record = perm_model.create!(
        target_model: "task",
        definition: { "roles" => { "admin" => {} }, "default_role" => "admin" }
      )
      LcpRuby::Permissions::Registry.reload!("task")
      expect(LcpRuby::Permissions::Registry.for_model("task")).not_to be_nil

      record.destroy!
      # after_commit triggers reload
      expect(LcpRuby::Permissions::Registry.for_model("task")).to be_nil
    end

    it "clears PolicyFactory cache when permission config changes" do
      expect(LcpRuby::Authorization::PolicyFactory).to receive(:clear!).at_least(:once)

      perm_model.create!(
        target_model: "task",
        definition: { "roles" => { "admin" => {} }, "default_role" => "admin" }
      )
    end
  end

  describe "Source resolution priority" do
    it "uses DB definition over YAML when DB record exists" do
      perm_model.create!(
        target_model: "task",
        definition: {
          "roles" => {
            "db_role" => {
              "crud" => %w[index show],
              "fields" => { "readable" => "all", "writable" => [] }
            }
          },
          "default_role" => "db_role"
        }
      )
      LcpRuby::Permissions::Registry.reload!("task")

      perm_def = LcpRuby.loader.permission_definition("task")
      expect(perm_def.default_role).to eq("db_role")
    end

    it "uses DB _default when model not found in DB" do
      perm_model.create!(
        target_model: "_default",
        definition: {
          "roles" => {
            "db_default" => {
              "crud" => %w[index show],
              "fields" => { "readable" => "all", "writable" => [] }
            }
          },
          "default_role" => "db_default"
        }
      )
      LcpRuby::Permissions::Registry.reload!

      perm_def = LcpRuby.loader.permission_definition("task")
      expect(perm_def.default_role).to eq("db_default")
    end

    it "falls back to YAML when no DB records exist" do
      perm_def = LcpRuby.loader.permission_definition("task")
      # YAML fixture defines yaml_viewer as default
      expect(perm_def.default_role).to eq("yaml_viewer")
    end
  end

  describe "PermissionEvaluator with DB permissions" do
    it "uses DB permission definition for authorization" do
      perm_model.create!(
        target_model: "task",
        definition: {
          "roles" => {
            "editor" => {
              "crud" => %w[index show update],
              "fields" => { "readable" => "all", "writable" => %w[title status] }
            }
          },
          "default_role" => "editor"
        }
      )
      LcpRuby::Permissions::Registry.reload!("task")
      LcpRuby::Authorization::PolicyFactory.clear!

      user = double("User", id: 1, lcp_role: %w[editor])
      perm_def = LcpRuby.loader.permission_definition("task")
      evaluator = LcpRuby::Authorization::PermissionEvaluator.new(perm_def, user, "task")

      expect(evaluator.can?(:index)).to be true
      expect(evaluator.can?(:update)).to be true
      expect(evaluator.can?(:destroy)).to be false
      expect(evaluator.writable_fields).to match_array(%w[title status])
    end
  end

  describe "Definition validation" do
    it "rejects invalid JSON structure" do
      record = perm_model.new(
        target_model: "task",
        definition: { "roles" => "not_a_hash" }
      )

      expect(record).not_to be_valid
      expect(record.errors[:definition]).to include(a_string_matching("must have a 'roles' key"))
    end

    it "rejects invalid CRUD actions" do
      record = perm_model.new(
        target_model: "task",
        definition: {
          "roles" => {
            "admin" => { "crud" => %w[index publish] }
          }
        }
      )

      expect(record).not_to be_valid
      expect(record.errors[:definition]).to include(a_string_matching("unknown actions: publish"))
    end

    it "accepts valid definitions" do
      record = perm_model.new(
        target_model: "task",
        definition: {
          "roles" => {
            "admin" => {
              "crud" => %w[index show create update destroy],
              "fields" => { "readable" => "all", "writable" => "all" }
            }
          },
          "default_role" => "admin"
        }
      )

      expect(record).to be_valid
    end
  end

  describe "CRUD operations on permission configs" do
    before do
      stub_current_user(role: "admin")
    end

    it "lists permission configs" do
      perm_model.create!(
        target_model: "task",
        definition: { "roles" => { "admin" => {} }, "default_role" => "admin" }
      )
      get "/permission-configs"
      expect(response).to have_http_status(:success)
    end

    it "shows a permission config" do
      record = perm_model.create!(
        target_model: "task",
        definition: { "roles" => { "admin" => {} }, "default_role" => "admin" }
      )
      get "/permission-configs/#{record.id}"
      expect(response).to have_http_status(:success)
    end

    it "creates a permission config" do
      post "/permission-configs", params: {
        record: {
          target_model: "task",
          definition: '{"roles":{"admin":{}},"default_role":"admin"}',
          active: "1"
        }
      }
      expect(response).to have_http_status(:redirect)
      follow_redirect!
      expect(response).to have_http_status(:success)
    end
  end

  describe "all_definitions for impersonation" do
    it "returns all active DB permission definitions" do
      perm_model.create!(
        target_model: "task",
        definition: {
          "roles" => { "admin" => {}, "editor" => {} },
          "default_role" => "editor"
        }
      )
      perm_model.create!(
        target_model: "_default",
        definition: {
          "roles" => { "viewer" => {} },
          "default_role" => "viewer"
        }
      )

      defs = LcpRuby::Permissions::Registry.all_definitions
      expect(defs.length).to eq(2)

      all_roles = defs.flat_map { |d| d.roles.keys }
      expect(all_roles).to include("admin", "editor", "viewer")
    end
  end
end
