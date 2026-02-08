require "spec_helper"

RSpec.describe LcpRuby::Metadata::Loader do
  let(:fixtures_path) { File.expand_path("../../../fixtures/metadata", __dir__) }
  let(:loader) { described_class.new(fixtures_path) }

  before { loader.load_all }

  describe "#load_all" do
    it "loads model definitions" do
      expect(loader.model_definitions).to have_key("project")
      expect(loader.model_definitions).to have_key("task")
    end

    it "loads presenter definitions" do
      expect(loader.presenter_definitions).to have_key("project_admin")
      expect(loader.presenter_definitions).to have_key("project_public")
    end

    it "loads permission definitions" do
      expect(loader.permission_definitions).to have_key("project")
      expect(loader.permission_definitions).to have_key("_default")
    end
  end

  describe "#model_definition" do
    it "returns a model definition by name" do
      model = loader.model_definition("project")
      expect(model).to be_a(LcpRuby::Metadata::ModelDefinition)
      expect(model.name).to eq("project")
    end

    it "raises for unknown model" do
      expect {
        loader.model_definition("nonexistent")
      }.to raise_error(LcpRuby::MetadataError, /not found/)
    end
  end

  describe "#presenter_definition" do
    it "returns a presenter definition by name" do
      presenter = loader.presenter_definition("project_admin")
      expect(presenter).to be_a(LcpRuby::Metadata::PresenterDefinition)
      expect(presenter.model).to eq("project")
    end
  end

  describe "#permission_definition" do
    it "returns model-specific permissions" do
      perm = loader.permission_definition("project")
      expect(perm.model).to eq("project")
    end

    it "falls back to default permissions for unknown models" do
      perm = loader.permission_definition("unknown")
      expect(perm.model).to eq("_default")
    end
  end

  describe "cross-reference validation" do
    it "validates that presenters reference existing models" do
      bad_path = Dir.mktmpdir
      FileUtils.mkdir_p(File.join(bad_path, "presenters"))

      File.write(File.join(bad_path, "presenters", "bad.yml"), <<~YAML)
        presenter:
          name: bad_presenter
          model: nonexistent
          slug: bad
      YAML

      bad_loader = described_class.new(bad_path)
      expect { bad_loader.load_all }.to raise_error(LcpRuby::MetadataError, /unknown model/)

      FileUtils.rm_rf(bad_path)
    end
  end
end
