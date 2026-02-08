require "spec_helper"

RSpec.describe LcpRuby::ModelFactory::Builder do
  let(:fixtures_path) { File.expand_path("../../../fixtures/metadata", __dir__) }
  let(:model_hash) do
    YAML.safe_load_file(File.join(fixtures_path, "models/project.yml"))["model"]
  end
  let(:model_definition) { LcpRuby::Metadata::ModelDefinition.from_hash(model_hash) }

  before do
    schema_manager = LcpRuby::ModelFactory::SchemaManager.new(model_definition)
    schema_manager.ensure_table!
  end

  after do
    ActiveRecord::Base.connection.drop_table(:projects) if ActiveRecord::Base.connection.table_exists?(:projects)
  end

  describe "#build" do
    subject(:model_class) { described_class.new(model_definition).build }

    it "creates a class under LcpRuby::Dynamic" do
      expect(model_class.name).to eq("LcpRuby::Dynamic::Project")
    end

    it "sets the correct table name" do
      expect(model_class.table_name).to eq("projects")
    end

    it "inherits from ActiveRecord::Base" do
      expect(model_class.superclass).to eq(ActiveRecord::Base)
    end

    describe "enums" do
      it "defines enum for status field" do
        expect(model_class.statuses).to eq(
          "draft" => "draft",
          "active" => "active",
          "completed" => "completed",
          "archived" => "archived"
        )
      end

      it "sets default enum value" do
        record = model_class.new
        expect(record.status).to eq("draft")
      end
    end

    describe "validations" do
      it "validates presence of title" do
        record = model_class.new(title: nil)
        expect(record).not_to be_valid
        expect(record.errors[:title]).to include("can't be blank")
      end

      it "validates length of title" do
        record = model_class.new(title: "ab")
        expect(record).not_to be_valid
        expect(record.errors[:title]).to include(/too short/)
      end

      it "validates numericality of budget" do
        record = model_class.new(title: "Valid Title", budget: -1)
        expect(record).not_to be_valid
        expect(record.errors[:budget]).to include(/greater than or equal to/)
      end

      it "allows nil budget" do
        record = model_class.new(title: "Valid Title", budget: nil)
        record.valid?
        expect(record.errors[:budget]).to be_empty
      end
    end

    describe "scopes" do
      before do
        model_class.create!(title: "Active Project", status: "active")
        model_class.create!(title: "Draft Project", status: "draft")
      end

      it "defines the active scope" do
        expect(model_class.active.count).to eq(1)
        expect(model_class.active.first.title).to eq("Active Project")
      end

      it "defines the recent scope" do
        records = model_class.recent
        expect(records.first.title).to eq("Draft Project")
      end

      it "defines the where_not scope (not_archived)" do
        model_class.create!(title: "Archived Project", status: "archived")
        results = model_class.not_archived
        expect(results.map(&:title)).to include("Active Project", "Draft Project")
        expect(results.map(&:title)).not_to include("Archived Project")
      end
    end

    describe "label method" do
      it "defines to_label method" do
        record = model_class.new(title: "My Project")
        expect(record.to_label).to eq("My Project")
      end
    end

    describe "CRUD operations" do
      it "creates and persists records" do
        record = model_class.create!(title: "Test Project")
        expect(record).to be_persisted
        expect(record.id).to be_present
      end

      it "reads records" do
        model_class.create!(title: "Find Me")
        found = model_class.find_by(title: "Find Me")
        expect(found).to be_present
      end

      it "updates records" do
        record = model_class.create!(title: "Before")
        record.update!(title: "After")
        expect(record.reload.title).to eq("After")
      end

      it "destroys records" do
        record = model_class.create!(title: "Delete Me")
        expect { record.destroy! }.to change(model_class, :count).by(-1)
      end
    end
  end
end
