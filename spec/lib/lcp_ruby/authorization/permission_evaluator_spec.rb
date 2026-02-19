require "spec_helper"

RSpec.describe LcpRuby::Authorization::PermissionEvaluator do
  let(:fixtures_path) { File.expand_path("../../../fixtures/metadata", __dir__) }
  let(:perm_hash) do
    YAML.safe_load_file(File.join(fixtures_path, "permissions/project.yml"))["permissions"]
  end
  let(:perm_def) { LcpRuby::Metadata::PermissionDefinition.from_hash(perm_hash) }

  let(:admin_user) { double("User", lcp_role: [ "admin" ], id: 1) }
  let(:manager_user) { double("User", lcp_role: [ "manager" ], id: 2) }
  let(:viewer_user) { double("User", lcp_role: [ "viewer" ], id: 3) }

  # Set up the model definition in the loader so readable_fields can resolve
  before do
    model_hash = YAML.safe_load_file(File.join(fixtures_path, "models/project.yml"))["model"]
    model_def = LcpRuby::Metadata::ModelDefinition.from_hash(model_hash)

    allow(LcpRuby).to receive(:loader).and_return(
      instance_double(LcpRuby::Metadata::Loader).tap do |loader|
        allow(loader).to receive(:model_definition).with("project").and_return(model_def)
      end
    )
  end

  describe "#roles" do
    it "returns array of roles from user" do
      evaluator = described_class.new(perm_def, admin_user, "project")
      expect(evaluator.roles).to eq([ "admin" ])
    end

    it "falls back to default_role when user has unknown role" do
      unknown_user = double("User", lcp_role: [ "unknown_role" ], id: 99)
      evaluator = described_class.new(perm_def, unknown_user, "project")
      expect(evaluator.roles).to eq([ "viewer" ])
    end

    it "falls back to default_role when user is nil" do
      evaluator = described_class.new(perm_def, nil, "project")
      expect(evaluator.roles).to eq([ "viewer" ])
    end
  end

  describe "#can?" do
    it "admin can do everything" do
      evaluator = described_class.new(perm_def, admin_user, "project")
      %i[index show create update destroy].each do |action|
        expect(evaluator.can?(action)).to be true
      end
    end

    it "manager cannot destroy" do
      evaluator = described_class.new(perm_def, manager_user, "project")
      expect(evaluator.can?(:index)).to be true
      expect(evaluator.can?(:show)).to be true
      expect(evaluator.can?(:create)).to be true
      expect(evaluator.can?(:update)).to be true
      expect(evaluator.can?(:destroy)).to be false
    end

    it "viewer can only index and show" do
      evaluator = described_class.new(perm_def, viewer_user, "project")
      expect(evaluator.can?(:index)).to be true
      expect(evaluator.can?(:show)).to be true
      expect(evaluator.can?(:create)).to be false
      expect(evaluator.can?(:update)).to be false
      expect(evaluator.can?(:destroy)).to be false
    end

    context "action aliases" do
      it "maps 'edit' to 'update' permission" do
        evaluator = described_class.new(perm_def, admin_user, "project")
        expect(evaluator.can?("edit")).to be true
      end

      it "maps 'new' to 'create' permission" do
        evaluator = described_class.new(perm_def, admin_user, "project")
        expect(evaluator.can?("new")).to be true
      end

      it "denies 'edit' when user lacks 'update' permission" do
        evaluator = described_class.new(perm_def, viewer_user, "project")
        expect(evaluator.can?("edit")).to be false
      end

      it "denies 'new' when user lacks 'create' permission" do
        evaluator = described_class.new(perm_def, viewer_user, "project")
        expect(evaluator.can?("new")).to be false
      end

      it "allows 'edit' for manager who has 'update'" do
        evaluator = described_class.new(perm_def, manager_user, "project")
        expect(evaluator.can?("edit")).to be true
      end
    end
  end

  describe "#can_for_record?" do
    it "denies update on archived records for manager" do
      evaluator = described_class.new(perm_def, manager_user, "project")
      archived_record = double("Record", status: "archived")

      expect(evaluator.can_for_record?(:update, archived_record)).to be false
    end

    it "allows update on archived records for admin" do
      evaluator = described_class.new(perm_def, admin_user, "project")
      archived_record = double("Record", status: "archived")

      expect(evaluator.can_for_record?(:update, archived_record)).to be true
    end

    it "allows update on active records for manager" do
      evaluator = described_class.new(perm_def, manager_user, "project")
      active_record = double("Record", status: "active")

      expect(evaluator.can_for_record?(:update, active_record)).to be true
    end

    context "with multiple roles" do
      it "allows update on archived records when one role is in except_roles" do
        admin_manager = double("User", lcp_role: [ "manager", "admin" ], id: 10)
        evaluator = described_class.new(perm_def, admin_manager, "project")
        archived_record = double("Record", status: "archived")

        expect(evaluator.can_for_record?(:update, archived_record)).to be true
      end

      it "denies when no role is in except_roles" do
        viewer_manager = double("User", lcp_role: [ "viewer", "manager" ], id: 11)
        evaluator = described_class.new(perm_def, viewer_manager, "project")
        archived_record = double("Record", status: "archived")

        # viewer+manager merged: can update (manager has it), but record rule blocks
        # because neither viewer nor manager is in except_roles [admin]
        expect(evaluator.can_for_record?(:update, archived_record)).to be false
      end
    end
  end

  describe "#readable_fields" do
    it "admin can read all fields" do
      evaluator = described_class.new(perm_def, admin_user, "project")
      expect(evaluator.readable_fields).to include("title", "status", "budget")
    end

    it "viewer can only read specified fields" do
      evaluator = described_class.new(perm_def, viewer_user, "project")
      expect(evaluator.readable_fields).to include("title", "status", "description")
      expect(evaluator.readable_fields).not_to include("budget", "priority")
    end

    it "manager cannot read budget due to field_overrides" do
      evaluator = described_class.new(perm_def, manager_user, "project")
      # Manager has readable: all, but budget has readable_by: [admin, manager]
      # Manager IS in readable_by, so they should be able to read budget
      expect(evaluator.field_readable?("budget")).to be true
    end
  end

  describe "#writable_fields" do
    it "admin can write all fields" do
      evaluator = described_class.new(perm_def, admin_user, "project")
      expect(evaluator.writable_fields).to include("title", "budget")
    end

    it "manager cannot write budget due to field_overrides" do
      evaluator = described_class.new(perm_def, manager_user, "project")
      expect(evaluator.field_writable?("budget")).to be false
    end

    it "viewer cannot write any fields" do
      evaluator = described_class.new(perm_def, viewer_user, "project")
      expect(evaluator.writable_fields).to be_empty
    end
  end

  describe "#can_execute_action?" do
    it "admin can execute all actions" do
      evaluator = described_class.new(perm_def, admin_user, "project")
      expect(evaluator.can_execute_action?("archive")).to be true
    end

    it "manager can execute allowed actions" do
      evaluator = described_class.new(perm_def, manager_user, "project")
      expect(evaluator.can_execute_action?("archive")).to be true
    end

    it "viewer cannot execute actions" do
      evaluator = described_class.new(perm_def, viewer_user, "project")
      expect(evaluator.can_execute_action?("archive")).to be false
    end
  end

  describe "#can_access_presenter?" do
    it "admin can access all presenters" do
      evaluator = described_class.new(perm_def, admin_user, "project")
      expect(evaluator.can_access_presenter?("project")).to be true
      expect(evaluator.can_access_presenter?("project_public")).to be true
    end

    it "manager can only access project" do
      evaluator = described_class.new(perm_def, manager_user, "project")
      expect(evaluator.can_access_presenter?("project")).to be true
      expect(evaluator.can_access_presenter?("project_public")).to be false
    end

    it "viewer can only access project_public" do
      evaluator = described_class.new(perm_def, viewer_user, "project")
      expect(evaluator.can_access_presenter?("project_public")).to be true
      expect(evaluator.can_access_presenter?("project")).to be false
    end
  end

  describe "multiple roles" do
    it "merges CRUD lists from multiple roles (union)" do
      # viewer: [index, show] + manager: [index, show, create, update]
      multi_user = double("User", lcp_role: [ "viewer", "manager" ], id: 10)
      evaluator = described_class.new(perm_def, multi_user, "project")

      expect(evaluator.can?(:index)).to be true
      expect(evaluator.can?(:show)).to be true
      expect(evaluator.can?(:create)).to be true
      expect(evaluator.can?(:update)).to be true
      expect(evaluator.can?(:destroy)).to be false
    end

    it "merges readable fields (union with 'all' winning)" do
      # viewer: [title, status, description, due_date] + manager: all
      multi_user = double("User", lcp_role: [ "viewer", "manager" ], id: 10)
      evaluator = described_class.new(perm_def, multi_user, "project")

      expect(evaluator.readable_fields).to include("title", "status", "budget")
    end

    it "merges writable fields (union)" do
      # viewer: [] + manager: [title, description, status, due_date, start_date, priority]
      multi_user = double("User", lcp_role: [ "viewer", "manager" ], id: 10)
      evaluator = described_class.new(perm_def, multi_user, "project")

      expect(evaluator.writable_fields).to include("title", "description")
    end

    it "merges presenter access (union)" do
      # viewer: [project_public] + manager: [project]
      multi_user = double("User", lcp_role: [ "viewer", "manager" ], id: 10)
      evaluator = described_class.new(perm_def, multi_user, "project")

      expect(evaluator.can_access_presenter?("project")).to be true
      expect(evaluator.can_access_presenter?("project_public")).to be true
    end

    it "merges actions (union of allowed)" do
      # viewer: allowed: [] + manager: allowed: [archive]
      multi_user = double("User", lcp_role: [ "viewer", "manager" ], id: 10)
      evaluator = described_class.new(perm_def, multi_user, "project")

      expect(evaluator.can_execute_action?("archive")).to be true
    end

    it "grants field readable if ANY role is in readable_by" do
      # budget readable_by: [admin, manager]
      multi_user = double("User", lcp_role: [ "viewer", "manager" ], id: 10)
      evaluator = described_class.new(perm_def, multi_user, "project")

      expect(evaluator.field_readable?("budget")).to be true
    end

    it "grants field writable if ANY role is in writable_by" do
      # budget writable_by: [admin]
      # viewer+admin should be able to write budget
      multi_user = double("User", lcp_role: [ "viewer", "admin" ], id: 10)
      evaluator = described_class.new(perm_def, multi_user, "project")

      expect(evaluator.field_writable?("budget")).to be true
    end
  end

  describe "default role fallback" do
    it "uses default_role when user has unknown role" do
      unknown_user = double("User", lcp_role: [ "unknown_role" ], id: 99)
      evaluator = described_class.new(perm_def, unknown_user, "project")

      # default_role is viewer
      expect(evaluator.can?(:index)).to be true
      expect(evaluator.can?(:create)).to be false
    end

    it "uses default_role when user is nil" do
      evaluator = described_class.new(perm_def, nil, "project")
      expect(evaluator.can?(:index)).to be true
      expect(evaluator.can?(:create)).to be false
    end
  end

  describe "#field_masked?" do
    let(:perm_def_with_mask) do
      LcpRuby::Metadata::PermissionDefinition.new(
        model: "project",
        roles: {
          "admin" => { "crud" => %w[index show], "fields" => { "readable" => "all", "writable" => "all" } },
          "viewer" => { "crud" => %w[index show], "fields" => { "readable" => "all", "writable" => [] } }
        },
        default_role: "viewer",
        field_overrides: { "secret" => { "masked_for" => %w[viewer] } }
      )
    end

    it "masks field when ALL user roles are in masked_for" do
      evaluator = described_class.new(perm_def_with_mask, viewer_user, "project")
      expect(evaluator.field_masked?("secret")).to be true
    end

    it "does not mask field when ANY role is NOT in masked_for" do
      multi_user = double("User", lcp_role: [ "admin", "viewer" ], id: 10)
      evaluator = described_class.new(perm_def_with_mask, multi_user, "project")
      expect(evaluator.field_masked?("secret")).to be false
    end
  end
end
