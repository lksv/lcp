require "spec_helper"

RSpec.describe "Loader DSL integration" do
  describe "loading DSL models alongside YAML models" do
    it "loads .rb model files from models directory" do
      Dir.mktmpdir do |dir|
        models_dir = File.join(dir, "models")
        FileUtils.mkdir_p(models_dir)

        File.write(File.join(models_dir, "widget.rb"), <<~RUBY)
          define_model :widget do
            label "Widget"
            field :name, :string do
              validates :presence
            end
            field :weight, :decimal, precision: 10, scale: 2
            timestamps true
            label_method :name
          end
        RUBY

        loader = LcpRuby::Metadata::Loader.new(dir)
        loader.load_models

        expect(loader.model_definitions).to have_key("widget")
        widget = loader.model_definition("widget")
        expect(widget.label).to eq("Widget")
        expect(widget.fields.length).to eq(2)
        expect(widget.field("name").validations.length).to eq(1)
      end
    end

    it "loads both YAML and DSL models" do
      Dir.mktmpdir do |dir|
        models_dir = File.join(dir, "models")
        FileUtils.mkdir_p(models_dir)

        # YAML model
        File.write(File.join(models_dir, "alpha.yml"), <<~YAML)
          model:
            name: alpha
            fields:
              - name: title
                type: string
        YAML

        # DSL model
        File.write(File.join(models_dir, "beta.rb"), <<~RUBY)
          define_model :beta do
            field :name, :string
          end
        RUBY

        loader = LcpRuby::Metadata::Loader.new(dir)
        loader.load_models

        expect(loader.model_definitions.keys).to contain_exactly("alpha", "beta")
      end
    end

    it "raises on duplicate model name between YAML and DSL" do
      Dir.mktmpdir do |dir|
        models_dir = File.join(dir, "models")
        FileUtils.mkdir_p(models_dir)

        # YAML model
        File.write(File.join(models_dir, "conflict.yml"), <<~YAML)
          model:
            name: conflict
            fields:
              - name: title
                type: string
        YAML

        # DSL model with same name
        File.write(File.join(models_dir, "conflict.rb"), <<~RUBY)
          define_model :conflict do
            field :name, :string
          end
        RUBY

        loader = LcpRuby::Metadata::Loader.new(dir)

        expect {
          loader.load_models
        }.to raise_error(LcpRuby::MetadataError, /Duplicate model 'conflict'/)
      end
    end

    it "raises on duplicate model name within DSL files" do
      Dir.mktmpdir do |dir|
        models_dir = File.join(dir, "models")
        FileUtils.mkdir_p(models_dir)

        File.write(File.join(models_dir, "dup_a.rb"), <<~RUBY)
          define_model :duplicate do
            field :name, :string
          end
        RUBY

        File.write(File.join(models_dir, "dup_b.rb"), <<~RUBY)
          define_model :duplicate do
            field :title, :string
          end
        RUBY

        loader = LcpRuby::Metadata::Loader.new(dir)

        expect {
          loader.load_models
        }.to raise_error(LcpRuby::MetadataError, /Duplicate model 'duplicate'/)
      end
    end
  end

  describe "LcpRuby.define_model" do
    it "returns a ModelDefinition" do
      definition = LcpRuby.define_model(:widget) do
        field :name, :string
      end

      expect(definition).to be_a(LcpRuby::Metadata::ModelDefinition)
      expect(definition.name).to eq("widget")
    end
  end
end
