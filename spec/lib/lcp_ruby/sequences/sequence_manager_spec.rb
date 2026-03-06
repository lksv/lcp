require "spec_helper"

RSpec.describe LcpRuby::Sequences::SequenceManager do
  before do
    LcpRuby::Types::BuiltInTypes.register_all!

    counter_definition = LcpRuby::Metadata::ModelDefinition.from_hash(counter_model_hash)
    LcpRuby::ModelFactory::SchemaManager.new(counter_definition).ensure_table!
    counter_class = LcpRuby::ModelFactory::Builder.new(counter_definition).build
    LcpRuby.registry.register("gapfree_sequence", counter_class)
  end

  after do
    conn = ActiveRecord::Base.connection
    conn.drop_table(:lcp_gapfree_sequences) if conn.table_exists?(:lcp_gapfree_sequences)
  end

  let(:counter_model_hash) do
    {
      "name" => "gapfree_sequence",
      "table_name" => "lcp_gapfree_sequences",
      "fields" => [
        { "name" => "seq_model", "type" => "string" },
        { "name" => "seq_field", "type" => "string" },
        { "name" => "scope_key", "type" => "string" },
        { "name" => "current_value", "type" => "integer", "default" => 0 }
      ],
      "indexes" => [
        { "columns" => %w[seq_model seq_field scope_key], "unique" => true }
      ],
      "options" => { "timestamps" => true }
    }
  end

  describe ".set" do
    it "creates a new counter row" do
      row = described_class.set(model: :invoice, field: :invoice_number, scope: { _year: 2026 }, value: 3500)
      expect(row.current_value).to eq(3500)
      expect(row.scope_key).to eq("_year:2026")
    end

    it "updates an existing counter row" do
      described_class.set(model: :invoice, field: :invoice_number, scope: { _year: 2026 }, value: 100)
      described_class.set(model: :invoice, field: :invoice_number, scope: { _year: 2026 }, value: 3500)

      expect(described_class.current(model: :invoice, field: :invoice_number, scope: { _year: 2026 })).to eq(3500)
    end
  end

  describe ".current" do
    it "returns nil for non-existent counter" do
      expect(described_class.current(model: :invoice, field: :invoice_number)).to be_nil
    end

    it "returns the current value" do
      described_class.set(model: :ticket, field: :code, value: 42)
      expect(described_class.current(model: :ticket, field: :code)).to eq(42)
    end

    it "handles global scope (empty hash)" do
      described_class.set(model: :ticket, field: :code, scope: {}, value: 10)
      expect(described_class.current(model: :ticket, field: :code, scope: {})).to eq(10)
    end
  end

  describe ".list" do
    it "returns all counters" do
      described_class.set(model: :invoice, field: :number, value: 10)
      described_class.set(model: :ticket, field: :code, value: 20)

      rows = described_class.list
      expect(rows.count).to eq(2)
    end

    it "filters by model name" do
      described_class.set(model: :invoice, field: :number, value: 10)
      described_class.set(model: :ticket, field: :code, value: 20)

      rows = described_class.list(model: :invoice)
      expect(rows.count).to eq(1)
      expect(rows.first.seq_model).to eq("invoice")
    end
  end
end
