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

    context "polymorphic belongs_to via update_table!" do
      let(:poly_hash) do
        {
          "name" => "note",
          "table_name" => "notes",
          "fields" => [
            { "name" => "body", "type" => "text" }
          ],
          "associations" => [
            {
              "type" => "belongs_to",
              "name" => "notable",
              "polymorphic" => true,
              "required" => false
            }
          ],
          "options" => { "timestamps" => false }
        }
      end
      let(:poly_definition) { LcpRuby::Metadata::ModelDefinition.from_hash(poly_hash) }
      let(:poly_manager) { described_class.new(poly_definition) }

      before do
        # Create table with only the body column — no FK columns yet
        ActiveRecord::Base.connection.create_table(:notes) do |t|
          t.text :body
        end
      end

      after do
        ActiveRecord::Base.connection.drop_table(:notes) if ActiveRecord::Base.connection.table_exists?(:notes)
      end

      it "adds both _id and _type columns for polymorphic belongs_to" do
        poly_manager.ensure_table!

        columns = ActiveRecord::Base.connection.columns(:notes).map(&:name)
        expect(columns).to include("notable_id")
        expect(columns).to include("notable_type")
      end

      it "creates composite index for polymorphic columns" do
        poly_manager.ensure_table!

        expect(ActiveRecord::Base.connection.index_exists?(:notes, %w[notable_id notable_type])).to be true
      end
    end
  end

  describe "#custom_data_index_name" do
    it "returns short name for normal table names" do
      name = schema_manager.send(:custom_data_index_name, "projects")
      expect(name).to eq("idx_projects_custom_data")
      expect(name.length).to be <= 63
    end

    it "truncates and hashes long table names" do
      long_table = "a_very_long_table_name_that_exceeds_the_postgresql_sixty_three_character_limit"
      name = schema_manager.send(:custom_data_index_name, long_table)
      expect(name.length).to be <= 63
      expect(name).to start_with("idx_")
      expect(name).to include("_cd_")
    end

    it "produces different names for different long tables" do
      table_a = "very_long_table_name_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      table_b = "very_long_table_name_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
      name_a = schema_manager.send(:custom_data_index_name, table_a)
      name_b = schema_manager.send(:custom_data_index_name, table_b)
      expect(name_a).not_to eq(name_b)
    end
  end
end
