require "spec_helper"

RSpec.describe LcpRuby::Dsl::DslLoader do
  let(:fixtures_path) { Pathname.new(File.expand_path("../../../fixtures/metadata", __dir__)) }
  let(:dsl_models_dir) { fixtures_path.join("models_dsl") }

  describe ".load_models" do
    it "loads model definitions from .rb files" do
      definitions = described_class.load_models(dsl_models_dir)

      expect(definitions).to have_key("project")
      expect(definitions["project"]).to be_a(LcpRuby::Metadata::ModelDefinition)
    end

    it "returns empty hash for non-existent directory" do
      definitions = described_class.load_models(Pathname.new("/nonexistent"))
      expect(definitions).to eq({})
    end

    it "produces a valid ModelDefinition from DSL" do
      definitions = described_class.load_models(dsl_models_dir)
      project = definitions["project"]

      expect(project.name).to eq("project")
      expect(project.label).to eq("Project")
      expect(project.label_plural).to eq("Projects")
      expect(project.fields.length).to eq(7)
      expect(project.scopes.length).to eq(3)
      expect(project.events.length).to eq(3)
      expect(project.associations.length).to eq(2)
      expect(project.timestamps?).to eq(true)
      expect(project.label_method).to eq("title")
    end

    it "parses fields correctly from DSL" do
      definitions = described_class.load_models(dsl_models_dir)
      project = definitions["project"]

      title = project.field("title")
      expect(title.type).to eq("string")
      expect(title.label).to eq("Title")
      expect(title.column_options).to eq({ limit: 255, null: false })
      expect(title.validations.length).to eq(2)
      expect(title.validations[0].type).to eq("presence")
      expect(title.validations[1].type).to eq("length")
      expect(title.validations[1].options).to eq({ minimum: 3, maximum: 255 })
    end

    it "parses enum fields from DSL" do
      definitions = described_class.load_models(dsl_models_dir)
      project = definitions["project"]

      status = project.field("status")
      expect(status.enum?).to be true
      expect(status.default).to eq("draft")
      expect(status.enum_value_names).to eq(%w[draft active completed archived])
    end
  end

  describe ".load_file" do
    it "raises MetadataError on Ruby syntax errors" do
      Dir.mktmpdir do |dir|
        bad_file = File.join(dir, "bad.rb")
        File.write(bad_file, "define_model :bad do\n  end end\nend")

        expect {
          described_class.load_file(bad_file)
        }.to raise_error(LcpRuby::MetadataError, /syntax error/)
      end
    end

    it "propagates MetadataError from invalid model definitions" do
      Dir.mktmpdir do |dir|
        bad_file = File.join(dir, "invalid.rb")
        File.write(bad_file, <<~RUBY)
          define_model :invalid do
            field :status, :not_a_real_type
          end
        RUBY

        expect {
          described_class.load_file(bad_file)
        }.to raise_error(LcpRuby::MetadataError, /invalid/)
      end
    end

    it "supports multiple models in a single file" do
      Dir.mktmpdir do |dir|
        multi_file = File.join(dir, "multi.rb")
        File.write(multi_file, <<~RUBY)
          define_model :alpha do
            field :name, :string
          end

          define_model :beta do
            field :title, :string
          end
        RUBY

        definitions = described_class.load_file(multi_file)
        expect(definitions.length).to eq(2)
        expect(definitions.map(&:name)).to contain_exactly("alpha", "beta")
      end
    end
  end
end
