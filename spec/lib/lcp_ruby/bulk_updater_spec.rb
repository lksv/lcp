require "spec_helper"

RSpec.describe LcpRuby::BulkUpdater do
  let(:model_definition) do
    LcpRuby::Metadata::ModelDefinition.from_hash(
      "name" => "bulk_item",
      "fields" => [
        { "name" => "title", "type" => "string" },
        { "name" => "status", "type" => "string" }
      ],
      "options" => { "timestamps" => false }
    )
  end

  let(:model_class) do
    LcpRuby::ModelFactory::SchemaManager.new(model_definition).ensure_table!
    LcpRuby::ModelFactory::Builder.new(model_definition).build
  end

  after do
    ActiveRecord::Base.connection.drop_table(:bulk_items) if ActiveRecord::Base.connection.table_exists?(:bulk_items)
  end

  describe ".tracked_update_all" do
    it "returns 0 for empty scope" do
      result = described_class.tracked_update_all(
        model_class.none,
        { status: "archived" },
        model_definition: model_definition
      )

      expect(result).to eq(0)
    end

    it "calls update_all and returns the row count" do
      model_class.create!(title: "Item 1", status: "active")
      model_class.create!(title: "Item 2", status: "active")

      result = described_class.tracked_update_all(
        model_class.where(status: "active"),
        { status: "archived" },
        model_definition: model_definition
      )

      expect(result).to eq(2)
      expect(model_class.where(status: "archived").count).to eq(2)
    end

    it "yields affected_ids, updates, and action to the block" do
      rec1 = model_class.create!(title: "Item 1", status: "active")
      rec2 = model_class.create!(title: "Item 2", status: "active")
      model_class.create!(title: "Item 3", status: "draft")

      yielded_args = nil
      described_class.tracked_update_all(
        model_class.where(status: "active"),
        { status: "archived" },
        action: :batch_discard,
        model_definition: model_definition
      ) do |ids, updates, action|
        yielded_args = { ids: ids, updates: updates, action: action }
      end

      expect(yielded_args[:ids]).to contain_exactly(rec1.id, rec2.id)
      expect(yielded_args[:updates]).to eq({ status: "archived" })
      expect(yielded_args[:action]).to eq(:batch_discard)
    end

    it "works without a block" do
      model_class.create!(title: "Item 1", status: "active")

      result = described_class.tracked_update_all(
        model_class.where(status: "active"),
        { status: "done" },
        model_definition: model_definition
      )

      expect(result).to eq(1)
    end

    it "does not yield when scope is empty" do
      yielded = false
      described_class.tracked_update_all(
        model_class.none,
        { status: "archived" },
        model_definition: model_definition
      ) { yielded = true }

      expect(yielded).to be false
    end
  end
end
