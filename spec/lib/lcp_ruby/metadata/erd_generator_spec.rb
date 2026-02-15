require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe LcpRuby::Metadata::ErdGenerator do
  let(:fixtures_path) { File.expand_path("../../../fixtures/metadata", __dir__) }
  let(:loader) { LcpRuby::Metadata::Loader.new(fixtures_path) }
  let(:generator) { described_class.new(loader) }

  before { loader.load_all }

  describe "#generate" do
    it "raises for unsupported format" do
      expect { generator.generate(:pdf) }.to raise_error(
        ArgumentError, /Unsupported format 'pdf'/
      )
    end

    it "accepts string format" do
      expect { generator.generate("mermaid") }.not_to raise_error
    end
  end

  # --- Mermaid ---

  describe "Mermaid format" do
    subject(:diagram) { generator.generate(:mermaid) }

    it "starts with erDiagram" do
      expect(diagram).to start_with("erDiagram")
    end

    it "includes model entities" do
      expect(diagram).to include("Project {")
      expect(diagram).to include("Task {")
    end

    it "includes fields with types" do
      expect(diagram).to include("string title")
      expect(diagram).to include("string status")
      expect(diagram).to include("float budget")
    end

    it "includes NOT NULL marker for required fields" do
      expect(diagram).to include('string title "NOT NULL"')
    end

    it "includes timestamp fields" do
      expect(diagram).to include("datetime created_at")
      expect(diagram).to include("datetime updated_at")
    end

    it "includes FK fields from belongs_to" do
      expect(diagram).to include("integer project_id FK")
    end

    it "includes relationships" do
      expect(diagram).to match(/Task.*\|\|.*Project/)
    end
  end

  # --- DOT/Graphviz ---

  describe "DOT format" do
    subject(:diagram) { generator.generate(:dot) }

    it "wraps in digraph" do
      expect(diagram).to start_with("digraph ERD {")
      expect(diagram).to end_with("}")
    end

    it "includes model nodes with record shape" do
      expect(diagram).to include("project [label=")
      expect(diagram).to include("task [label=")
    end

    it "includes fields in label" do
      expect(diagram).to include("title : string")
      expect(diagram).to include("status : enum")
    end

    it "includes NOT NULL marker" do
      expect(diagram).to include("title : string NOT NULL")
    end

    it "includes FK fields" do
      expect(diagram).to include("project_id : integer FK")
    end

    it "includes edges for relationships" do
      expect(diagram).to include("task -> project")
    end

    it "uses solid style for required associations" do
      expect(diagram).to match(/task -> project.*style=solid/)
    end
  end

  # --- PlantUML ---

  describe "PlantUML format" do
    subject(:diagram) { generator.generate(:plantuml) }

    it "wraps in @startuml/@enduml" do
      expect(diagram).to include("@startuml")
      expect(diagram).to include("@enduml")
    end

    it "includes entity definitions" do
      expect(diagram).to include('entity "Project" as project {')
      expect(diagram).to include('entity "Task" as task {')
    end

    it "includes PK" do
      expect(diagram).to include("* id : integer <<PK>>")
    end

    it "includes fields" do
      expect(diagram).to include("title : string")
      expect(diagram).to include("status : enum")
    end

    it "marks required fields with asterisk" do
      expect(diagram).to include("* title : string")
    end

    it "includes FK with stereotype" do
      expect(diagram).to include("project_id : integer <<FK>>")
    end

    it "includes relationships" do
      expect(diagram).to match(/task.*\|\|.*project/)
    end
  end

  # --- CRM multi-model scenario ---

  context "with CRM fixtures" do
    let(:fixtures_path) { File.expand_path("../../../fixtures/integration/crm", __dir__) }

    describe "Mermaid format" do
      subject(:diagram) { generator.generate(:mermaid) }

      it "includes all three models" do
        expect(diagram).to include("Company {")
        expect(diagram).to include("Contact {")
        expect(diagram).to include("Deal {")
      end

      it "includes deal->company relationship" do
        expect(diagram).to match(/Deal.*\|\|.*Company/)
      end

      it "includes deal->contact relationship" do
        expect(diagram).to match(/Deal.*\|\|.*Contact/)
      end
    end

    describe "DOT format" do
      subject(:diagram) { generator.generate(:dot) }

      it "includes all three models" do
        expect(diagram).to include("company [label=")
        expect(diagram).to include("contact [label=")
        expect(diagram).to include("deal [label=")
      end

      it "includes association edges" do
        expect(diagram).to include("deal -> company")
        expect(diagram).to include("deal -> contact")
      end

      it "uses dashed style for optional associations" do
        # contact association is optional (required: false)
        expect(diagram).to match(/deal -> contact.*style=dashed/)
      end
    end
  end

  # --- Polymorphic associations ---

  context "with polymorphic associations" do
    let(:tmpdir) do
      dir = Dir.mktmpdir("lcp_test")
      FileUtils.mkdir_p(File.join(dir, "models"))
      File.write(File.join(dir, "models", "comment.yml"), <<~YAML)
        model:
          name: comment
          fields:
            - { name: body, type: text }
          associations:
            - type: belongs_to
              name: commentable
              polymorphic: true
              required: false
          options:
            timestamps: false
      YAML
      dir
    end

    after { FileUtils.rm_rf(tmpdir) }

    let(:fixtures_path) { tmpdir }
    let(:loader) do
      l = LcpRuby::Metadata::Loader.new(tmpdir)
      l.load_all
      l
    end
    let(:generator) { described_class.new(loader) }

    it "includes _type field in Mermaid entity" do
      diagram = generator.generate(:mermaid)
      expect(diagram).to include("integer commentable_id FK")
      expect(diagram).to include("string commentable_type")
    end

    it "does not render relationship edge for polymorphic belongs_to" do
      diagram = generator.generate(:mermaid)
      # Polymorphic has no target_model, so no edge
      expect(diagram).not_to match(/Comment.*\|\|/)
    end

    it "includes _type field in DOT entity" do
      diagram = generator.generate(:dot)
      expect(diagram).to include("commentable_type : string")
    end

    it "includes _type field in PlantUML entity" do
      diagram = generator.generate(:plantuml)
      expect(diagram).to include("commentable_type : string")
    end
  end

  # --- Through associations ---

  context "with through associations" do
    let(:tmpdir) do
      dir = Dir.mktmpdir("lcp_test")
      FileUtils.mkdir_p(File.join(dir, "models"))
      File.write(File.join(dir, "models", "post.yml"), <<~YAML)
        model:
          name: post
          fields:
            - { name: title, type: string }
          associations:
            - type: has_many
              name: taggings
              target_model: tagging
            - type: has_many
              name: tags
              through: taggings
          options:
            timestamps: false
      YAML
      File.write(File.join(dir, "models", "tagging.yml"), <<~YAML)
        model:
          name: tagging
          fields: []
          associations:
            - type: belongs_to
              name: post
              target_model: post
            - type: belongs_to
              name: tag
              target_model: tag
          options:
            timestamps: false
      YAML
      File.write(File.join(dir, "models", "tag.yml"), <<~YAML)
        model:
          name: tag
          fields:
            - { name: label, type: string }
          options:
            timestamps: false
      YAML
      dir
    end

    after { FileUtils.rm_rf(tmpdir) }

    let(:fixtures_path) { tmpdir }
    let(:loader) do
      l = LcpRuby::Metadata::Loader.new(tmpdir)
      l.load_all
      l
    end
    let(:generator) { described_class.new(loader) }

    it "does not render edge for through association in Mermaid" do
      diagram = generator.generate(:mermaid)
      # The through association (tags) should not create a direct edge
      # but the belongs_to edges from tagging should exist
      expect(diagram).to match(/Tagging.*\|\|.*Post/)
      expect(diagram).to match(/Tagging.*\|\|.*Tag/)
    end

    it "does not render edge for through association in DOT" do
      diagram = generator.generate(:dot)
      expect(diagram).to include("tagging -> post")
      expect(diagram).to include("tagging -> tag")
      # through assoc (post -> tags) should NOT create a direct edge
      lines = diagram.lines.select { |l| l.include?("->") }
      expect(lines.count).to eq(2) # only tagging -> post and tagging -> tag
    end

    it "does not render edge for through association in PlantUML" do
      diagram = generator.generate(:plantuml)
      # belongs_to edges from tagging should exist
      expect(diagram).to match(/tagging.*\|\|.*post/)
      expect(diagram).to match(/tagging.*\|\|.*tag/)
      # through assoc (post -> tags) should NOT create a direct edge
      relationship_lines = diagram.lines.select { |l| l.include?("}") && l.include?("||") }
      expect(relationship_lines.count).to eq(2)
    end
  end

  # --- Edge case: no associations ---

  context "with a model without associations" do
    let(:tmpdir) do
      dir = Dir.mktmpdir("lcp_test")
      FileUtils.mkdir_p(File.join(dir, "models"))
      File.write(File.join(dir, "models", "standalone.yml"), <<~YAML)
        model:
          name: standalone
          fields:
            - { name: title, type: string }
            - { name: active, type: boolean }
          options:
            timestamps: false
      YAML
      dir
    end

    after { FileUtils.rm_rf(tmpdir) }

    let(:fixtures_path) { tmpdir }
    let(:loader) do
      l = LcpRuby::Metadata::Loader.new(tmpdir)
      l.load_all
      l
    end
    let(:generator) { described_class.new(loader) }

    it "generates mermaid without relationships" do
      diagram = generator.generate(:mermaid)
      expect(diagram).to include("Standalone {")
      expect(diagram).to include("string title")
      expect(diagram).to include("bool active")
      expect(diagram).not_to include("--")
    end

    it "generates dot without edges" do
      diagram = generator.generate(:dot)
      expect(diagram).to include("standalone [label=")
      expect(diagram).not_to include("->")
    end

    it "does not include timestamps when disabled" do
      diagram = generator.generate(:mermaid)
      expect(diagram).not_to include("created_at")
    end
  end
end
