require "spec_helper"

RSpec.describe LcpRuby::ModelFactory::SchemaManager do
  let(:fixtures_path) { File.expand_path("../../../fixtures/metadata", __dir__) }
  let(:model_hash) do
    YAML.safe_load_file(File.join(fixtures_path, "models/project.yml"))["model"]
  end
  let(:model_definition) { LcpRuby::Metadata::ModelDefinition.from_hash(model_hash) }
  let(:schema_manager) { described_class.new(model_definition) }

  after do
    ActiveRecord::Base.connection.drop_table(:projects) if ActiveRecord::Base.connection.table_exists?(:projects)
  end

  describe "#ensure_table!" do
    it "creates the table when it does not exist" do
      expect(ActiveRecord::Base.connection.table_exists?(:projects)).to be false

      schema_manager.ensure_table!

      expect(ActiveRecord::Base.connection.table_exists?(:projects)).to be true
    end

    it "creates columns for all defined fields" do
      schema_manager.ensure_table!

      columns = ActiveRecord::Base.connection.columns(:projects).map(&:name)
      expect(columns).to include("title", "status", "description", "budget", "due_date", "start_date", "priority")
    end

    it "creates timestamp columns" do
      schema_manager.ensure_table!

      columns = ActiveRecord::Base.connection.columns(:projects).map(&:name)
      expect(columns).to include("created_at", "updated_at")
    end

    it "sets correct column types" do
      schema_manager.ensure_table!

      col = ActiveRecord::Base.connection.columns(:projects).find { |c| c.name == "budget" }
      expect(col.type).to eq(:decimal)
    end

    context "when table already exists" do
      before do
        ActiveRecord::Base.connection.create_table(:projects) do |t|
          t.string :title
          t.timestamps
        end
      end

      it "adds missing columns" do
        schema_manager.ensure_table!

        columns = ActiveRecord::Base.connection.columns(:projects).map(&:name)
        expect(columns).to include("status", "description", "budget")
      end

      it "does not re-add existing columns" do
        expect {
          schema_manager.ensure_table!
        }.not_to raise_error
      end
    end
  end
end
