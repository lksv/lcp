require "spec_helper"
require "generators/lcp_ruby/custom_fields_generator"

RSpec.describe LcpRuby::Generators::CustomFieldsGenerator do
  include FileUtils

  let(:destination) { Dir.mktmpdir("lcp_ruby_generator_test") }

  before do
    # Set up the destination directory structure required by the generator
    %w[config/lcp_ruby/models config/lcp_ruby/presenters config/lcp_ruby/permissions config/lcp_ruby/views].each do |dir|
      mkdir_p(File.join(destination, dir))
    end
  end

  after do
    rm_rf(destination)
  end

  def run_generator(args = [])
    described_class.start(args, destination_root: destination, shell: Thor::Shell::Basic.new)
  end

  def build_generator(options = {})
    described_class.new([], options, destination_root: destination, shell: Thor::Shell::Basic.new)
  end

  describe "with default (DSL) format" do
    before { run_generator }

    it "creates DSL model file" do
      path = File.join(destination, "config/lcp_ruby/models/custom_field_definition.rb")
      expect(File.exist?(path)).to be true
      content = File.read(path)
      expect(content).to include("define_model :custom_field_definition")
      expect(content).to include("field :field_name, :string")
      expect(content).to include("field :custom_type, :string")
      expect(content).to include("field :target_model, :string")
      expect(content).to include("field :active, :boolean")
      expect(content).to include("validates :field_name, :uniqueness, scope: :target_model")
    end

    it "creates DSL presenter file" do
      path = File.join(destination, "config/lcp_ruby/presenters/custom_fields.rb")
      expect(File.exist?(path)).to be true
      content = File.read(path)
      expect(content).to include("define_presenter :custom_fields")
      expect(content).to include("model :custom_field_definition")
      expect(content).to include('slug "custom-fields"')
    end

    it "creates YAML permissions file" do
      path = File.join(destination, "config/lcp_ruby/permissions/custom_field_definition.yml")
      expect(File.exist?(path)).to be true
      content = File.read(path)
      expect(content).to include("model: custom_field_definition")
      expect(content).to include("admin:")
      expect(content).to include("viewer:")
      expect(content).to include("default_role: viewer")
    end

    it "creates DSL view group file" do
      path = File.join(destination, "config/lcp_ruby/views/custom_fields.rb")
      expect(File.exist?(path)).to be true
      content = File.read(path)
      expect(content).to include("define_view_group :custom_fields")
      expect(content).to include("model :custom_field_definition")
    end

    it "does not create YAML model or presenter" do
      expect(File.exist?(File.join(destination, "config/lcp_ruby/models/custom_field_definition.yml"))).to be false
      expect(File.exist?(File.join(destination, "config/lcp_ruby/presenters/custom_fields.yml"))).to be false
    end
  end

  describe "with YAML format" do
    before { run_generator([ "--format=yaml" ]) }

    it "creates YAML model file" do
      path = File.join(destination, "config/lcp_ruby/models/custom_field_definition.yml")
      expect(File.exist?(path)).to be true
      content = File.read(path)
      expect(content).to include("name: custom_field_definition")
      expect(content).to include("name: field_name")
      expect(content).to include("name: custom_type")
      expect(content).to include("type: uniqueness")
    end

    it "creates YAML presenter file" do
      path = File.join(destination, "config/lcp_ruby/presenters/custom_fields.yml")
      expect(File.exist?(path)).to be true
      content = File.read(path)
      expect(content).to include("name: custom_fields")
      expect(content).to include("model: custom_field_definition")
      expect(content).to include("slug: custom-fields")
    end

    it "creates YAML permissions file" do
      path = File.join(destination, "config/lcp_ruby/permissions/custom_field_definition.yml")
      expect(File.exist?(path)).to be true
    end

    it "creates YAML view group file" do
      path = File.join(destination, "config/lcp_ruby/views/custom_fields.yml")
      expect(File.exist?(path)).to be true
      content = File.read(path)
      expect(content).to include("model: custom_field_definition")
      expect(content).to include("primary: custom_fields")
    end

    it "does not create DSL model or presenter" do
      expect(File.exist?(File.join(destination, "config/lcp_ruby/models/custom_field_definition.rb"))).to be false
      expect(File.exist?(File.join(destination, "config/lcp_ruby/presenters/custom_fields.rb"))).to be false
    end
  end

  describe "with invalid format" do
    it "raises Thor::Error from validate_format" do
      gen = build_generator(format: "xml")
      expect { gen.validate_format }.to raise_error(Thor::Error, /Invalid format 'xml'/)
    end
  end
end
