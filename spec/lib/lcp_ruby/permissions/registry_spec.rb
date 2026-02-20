require "spec_helper"

RSpec.describe LcpRuby::Permissions::Registry do
  before do
    LcpRuby.reset!
  end

  describe ".available?" do
    it "returns false by default" do
      expect(described_class).not_to be_available
    end

    it "returns true after mark_available!" do
      described_class.mark_available!
      expect(described_class).to be_available
    end
  end

  describe ".for_model" do
    it "returns nil when not available" do
      expect(described_class.for_model("project")).to be_nil
    end

    context "when available" do
      let(:perm_record) do
        double("PermissionConfig",
          target_model: "project",
          definition: {
            "roles" => { "admin" => { "crud" => %w[index show create update destroy] } },
            "default_role" => "admin"
          })
      end

      let(:model_class) do
        scope = double("Scope")
        allow(scope).to receive(:where).and_return(scope)
        allow(scope).to receive(:order).and_return(scope)
        allow(scope).to receive(:last).and_return(perm_record)
        allow(scope).to receive(:column_names).and_return(%w[id target_model definition active])

        klass = double("PermissionConfigModel")
        allow(klass).to receive(:where).and_return(scope)
        allow(klass).to receive(:column_names).and_return(%w[id target_model definition active])
        klass
      end

      before do
        described_class.mark_available!
        allow(LcpRuby.configuration).to receive(:permission_model).and_return("permission_config")
        allow(LcpRuby.configuration).to receive(:permission_model_fields).and_return({
          target_model: "target_model", definition: "definition", active: "active"
        })
        allow(LcpRuby.registry).to receive(:model_for).with("permission_config").and_return(model_class)
      end

      it "returns a parsed PermissionDefinition" do
        result = described_class.for_model("project")
        expect(result).to be_a(LcpRuby::Metadata::PermissionDefinition)
        expect(result.roles).to have_key("admin")
      end

      it "caches the result" do
        described_class.for_model("project")
        described_class.for_model("project")
        # where should be called only once (second call hits cache)
        expect(model_class).to have_received(:where).once
      end

      it "returns nil when no matching record found" do
        scope = double("EmptyScope")
        allow(scope).to receive(:where).and_return(scope)
        allow(scope).to receive(:order).and_return(scope)
        allow(scope).to receive(:last).and_return(nil)
        allow(model_class).to receive(:where).and_return(scope)

        result = described_class.for_model("nonexistent")
        expect(result).to be_nil
      end
    end
  end

  describe ".reload!" do
    it "clears cache for specific model" do
      described_class.mark_available!
      # Prime internal cache state
      described_class.instance_variable_get(:@cache)["project"] = "cached"

      described_class.reload!("project")

      cache = described_class.instance_variable_get(:@cache)
      expect(cache).not_to have_key("project")
    end

    it "clears all cache when no model specified" do
      described_class.mark_available!
      described_class.instance_variable_get(:@cache)["project"] = "cached"
      described_class.instance_variable_get(:@cache)["task"] = "cached"

      described_class.reload!

      cache = described_class.instance_variable_get(:@cache)
      expect(cache).to be_empty
    end
  end

  describe ".clear!" do
    it "resets availability and cache" do
      described_class.mark_available!
      described_class.clear!

      expect(described_class).not_to be_available
    end
  end

  describe ".for_model with JSON string definition" do
    let(:perm_record) do
      double("PermissionConfig",
        target_model: "project",
        definition: '{"roles":{"admin":{"crud":["index","show"]}},"default_role":"admin"}')
    end

    let(:model_class) do
      scope = double("Scope")
      allow(scope).to receive(:where).and_return(scope)
      allow(scope).to receive(:order).and_return(scope)
      allow(scope).to receive(:last).and_return(perm_record)

      klass = double("PermissionConfigModel")
      allow(klass).to receive(:where).and_return(scope)
      allow(klass).to receive(:column_names).and_return(%w[id target_model definition active])
      klass
    end

    before do
      described_class.mark_available!
      allow(LcpRuby.configuration).to receive(:permission_model).and_return("permission_config")
      allow(LcpRuby.configuration).to receive(:permission_model_fields).and_return({
        target_model: "target_model", definition: "definition", active: "active"
      })
      allow(LcpRuby.registry).to receive(:model_for).with("permission_config").and_return(model_class)
    end

    it "parses JSON string definitions" do
      result = described_class.for_model("project")
      expect(result).to be_a(LcpRuby::Metadata::PermissionDefinition)
      expect(result.roles).to have_key("admin")
    end
  end
end
