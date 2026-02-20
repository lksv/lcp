require "spec_helper"

RSpec.describe LcpRuby::Permissions::SourceResolver do
  let(:loader) { instance_double(LcpRuby::Metadata::Loader) }
  let(:yaml_perm_def) { LcpRuby::Metadata::PermissionDefinition.new(model: "project", roles: { "admin" => {} }, default_role: "admin") }
  let(:yaml_default_def) { LcpRuby::Metadata::PermissionDefinition.new(model: "_default", roles: { "viewer" => {} }, default_role: "viewer") }
  let(:db_perm_def) { LcpRuby::Metadata::PermissionDefinition.new(model: "project", roles: { "db_admin" => {} }, default_role: "db_admin") }
  let(:db_default_def) { LcpRuby::Metadata::PermissionDefinition.new(model: "_default", roles: { "db_viewer" => {} }, default_role: "db_viewer") }

  before do
    LcpRuby.reset!
  end

  describe ".for" do
    context "when permission_source is :yaml" do
      before do
        LcpRuby.configuration.permission_source = :yaml
      end

      it "returns YAML permission definition" do
        allow(loader).to receive(:yaml_permission_definition).with("project").and_return(yaml_perm_def)

        result = described_class.for("project", loader)
        expect(result).to eq(yaml_perm_def)
      end
    end

    context "when permission_source is :model" do
      before do
        LcpRuby.configuration.permission_source = :model
      end

      context "when registry is not available" do
        it "falls back to YAML" do
          allow(loader).to receive(:yaml_permission_definition).with("project").and_return(yaml_perm_def)

          result = described_class.for("project", loader)
          expect(result).to eq(yaml_perm_def)
        end
      end

      context "when registry is available" do
        before do
          LcpRuby::Permissions::Registry.mark_available!
        end

        it "returns DB definition when found for the model" do
          allow(LcpRuby::Permissions::Registry).to receive(:for_model).with("project").and_return(db_perm_def)

          result = described_class.for("project", loader)
          expect(result).to eq(db_perm_def)
        end

        it "returns DB _default when model not found in DB" do
          allow(LcpRuby::Permissions::Registry).to receive(:for_model).with("project").and_return(nil)
          allow(LcpRuby::Permissions::Registry).to receive(:for_model).with("_default").and_return(db_default_def)

          result = described_class.for("project", loader)
          expect(result).to eq(db_default_def)
        end

        it "falls back to YAML when neither model nor _default in DB" do
          allow(LcpRuby::Permissions::Registry).to receive(:for_model).with("project").and_return(nil)
          allow(LcpRuby::Permissions::Registry).to receive(:for_model).with("_default").and_return(nil)
          allow(loader).to receive(:yaml_permission_definition).with("project").and_return(yaml_perm_def)

          result = described_class.for("project", loader)
          expect(result).to eq(yaml_perm_def)
        end
      end
    end
  end
end
