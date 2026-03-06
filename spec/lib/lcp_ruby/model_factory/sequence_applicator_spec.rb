require "spec_helper"

RSpec.describe LcpRuby::ModelFactory::SequenceApplicator do
  before do
    LcpRuby::Types::BuiltInTypes.register_all!
    LcpRuby::Services::BuiltInTransforms.register_all!
    LcpRuby::Services::BuiltInDefaults.register_all!

    # Build the gapfree_sequence counter table
    counter_definition = LcpRuby::Metadata::ModelDefinition.from_hash(counter_model_hash)
    LcpRuby::ModelFactory::SchemaManager.new(counter_definition).ensure_table!
    counter_class = LcpRuby::ModelFactory::Builder.new(counter_definition).build
    LcpRuby.registry.register("gapfree_sequence", counter_class)
  end

  after do
    conn = ActiveRecord::Base.connection
    conn.drop_table(:items) if conn.table_exists?(:items)
    conn.drop_table(:departments) if conn.table_exists?(:departments)
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

  def build_full_model(model_hash)
    model_definition = LcpRuby::Metadata::ModelDefinition.from_hash(model_hash)
    LcpRuby::ModelFactory::SchemaManager.new(model_definition).ensure_table!
    model_class = LcpRuby::ModelFactory::Builder.new(model_definition).build
    model_class.reset_column_information
    model_class
  end

  describe "global sequence (no scope)" do
    let(:model_hash) do
      {
        "name" => "item",
        "fields" => [
          { "name" => "code", "type" => "string",
            "sequence" => { "format" => "TKT-%{sequence:06d}" } },
          { "name" => "title", "type" => "string" }
        ],
        "options" => { "timestamps" => false }
      }
    end

    it "assigns sequential values on create" do
      model_class = build_full_model(model_hash)

      r1 = model_class.create!(title: "First")
      r2 = model_class.create!(title: "Second")
      r3 = model_class.create!(title: "Third")

      expect(r1.code).to eq("TKT-000001")
      expect(r2.code).to eq("TKT-000002")
      expect(r3.code).to eq("TKT-000003")
    end

    it "does not change code on update" do
      model_class = build_full_model(model_hash)
      record = model_class.create!(title: "First")
      original_code = record.code

      record.update!(title: "Updated")
      expect(record.code).to eq(original_code)
    end
  end

  describe "yearly scope" do
    let(:model_hash) do
      {
        "name" => "item",
        "fields" => [
          { "name" => "invoice_number", "type" => "string",
            "sequence" => {
              "scope" => ["_year"],
              "format" => "INV-%{_year}-%{sequence:04d}"
            } },
          { "name" => "amount", "type" => "decimal" }
        ]
      }
    end

    it "assigns formatted value with year" do
      model_class = build_full_model(model_hash)
      record = model_class.create!(amount: 100.0)

      year = Time.current.strftime("%Y")
      expect(record.invoice_number).to eq("INV-#{year}-0001")
    end

    it "increments within the same year scope" do
      model_class = build_full_model(model_hash)
      r1 = model_class.create!(amount: 100.0)
      r2 = model_class.create!(amount: 200.0)

      year = Time.current.strftime("%Y")
      expect(r1.invoice_number).to eq("INV-#{year}-0001")
      expect(r2.invoice_number).to eq("INV-#{year}-0002")
    end
  end

  describe "field-based scope" do
    let(:model_hash) do
      {
        "name" => "item",
        "fields" => [
          { "name" => "reg_number", "type" => "string",
            "sequence" => {
              "scope" => ["department_id"],
              "format" => "DOC-%{sequence:05d}"
            } },
          { "name" => "department_id", "type" => "integer" },
          { "name" => "title", "type" => "string" }
        ],
        "options" => { "timestamps" => false }
      }
    end

    it "maintains independent counters per scope" do
      model_class = build_full_model(model_hash)

      d1_r1 = model_class.create!(department_id: 1, title: "A")
      d1_r2 = model_class.create!(department_id: 1, title: "B")
      d2_r1 = model_class.create!(department_id: 2, title: "C")

      expect(d1_r1.reg_number).to eq("DOC-00001")
      expect(d1_r2.reg_number).to eq("DOC-00002")
      expect(d2_r1.reg_number).to eq("DOC-00001")
    end
  end

  describe "custom start and step" do
    let(:model_hash) do
      {
        "name" => "item",
        "fields" => [
          { "name" => "order_seq", "type" => "integer",
            "sequence" => { "start" => 1000, "step" => 5 } },
          { "name" => "title", "type" => "string" }
        ],
        "options" => { "timestamps" => false }
      }
    end

    it "starts at custom value and increments by step" do
      model_class = build_full_model(model_hash)

      r1 = model_class.create!(title: "A")
      r2 = model_class.create!(title: "B")
      r3 = model_class.create!(title: "C")

      expect(r1.order_seq).to eq(1000)
      expect(r2.order_seq).to eq(1005)
      expect(r3.order_seq).to eq(1010)
    end
  end

  describe "integer field without format" do
    let(:model_hash) do
      {
        "name" => "item",
        "fields" => [
          { "name" => "seq", "type" => "integer",
            "sequence" => {} },
          { "name" => "title", "type" => "string" }
        ],
        "options" => { "timestamps" => false }
      }
    end

    it "assigns raw integer counter" do
      model_class = build_full_model(model_hash)

      r1 = model_class.create!(title: "A")
      r2 = model_class.create!(title: "B")

      expect(r1.seq).to eq(1)
      expect(r2.seq).to eq(2)
    end
  end

  describe "assign_on: always" do
    let(:model_hash) do
      {
        "name" => "item",
        "fields" => [
          { "name" => "code", "type" => "string",
            "sequence" => {
              "format" => "CODE-%{sequence:04d}",
              "assign_on" => "always"
            } },
          { "name" => "title", "type" => "string" }
        ],
        "options" => { "timestamps" => false }
      }
    end

    it "assigns on create" do
      model_class = build_full_model(model_hash)
      record = model_class.create!(title: "A")
      expect(record.code).to eq("CODE-0001")
    end

    it "fills blank value on update" do
      model_class = build_full_model(model_hash)
      record = model_class.create!(title: "A")
      expect(record.code).to eq("CODE-0001")

      # Manually blank the code to simulate import scenario
      model_class.where(id: record.id).update_all(code: nil)
      record = model_class.find(record.id)

      record.update!(title: "Updated")
      record.reload
      expect(record.code).to eq("CODE-0002")
    end

    it "does not reassign when value is present" do
      model_class = build_full_model(model_hash)
      record = model_class.create!(title: "A")
      original = record.code

      record.update!(title: "Updated")
      expect(record.code).to eq(original)
    end
  end

  describe "multiple sequence fields per model" do
    let(:model_hash) do
      {
        "name" => "item",
        "fields" => [
          { "name" => "reg_number", "type" => "string",
            "sequence" => { "format" => "REG-%{sequence:04d}" } },
          { "name" => "global_seq", "type" => "string",
            "sequence" => { "format" => "GBL-%{sequence:06d}" } },
          { "name" => "title", "type" => "string" }
        ],
        "options" => { "timestamps" => false }
      }
    end

    it "assigns independent counters for each field" do
      model_class = build_full_model(model_hash)
      record = model_class.create!(title: "A")

      expect(record.reg_number).to eq("REG-0001")
      expect(record.global_seq).to eq("GBL-000001")
    end
  end

  describe "format with field references" do
    let(:model_hash) do
      {
        "name" => "item",
        "fields" => [
          { "name" => "code", "type" => "string",
            "sequence" => {
              "scope" => ["dept_code"],
              "format" => "%{dept_code}-%{sequence:04d}"
            } },
          { "name" => "dept_code", "type" => "string" },
          { "name" => "title", "type" => "string" }
        ],
        "options" => { "timestamps" => false }
      }
    end

    it "interpolates field values into format" do
      model_class = build_full_model(model_hash)

      r1 = model_class.create!(dept_code: "HR", title: "A")
      r2 = model_class.create!(dept_code: "FIN", title: "B")
      r3 = model_class.create!(dept_code: "HR", title: "C")

      expect(r1.code).to eq("HR-0001")
      expect(r2.code).to eq("FIN-0001")
      expect(r3.code).to eq("HR-0002")
    end
  end

  describe "LcpRuby::Sequences.build_scope_key" do
    it "returns _global for empty scope" do
      key = LcpRuby::Sequences.build_scope_key({})
      expect(key).to eq("_global")
    end

    it "returns _global for nil" do
      key = LcpRuby::Sequences.build_scope_key(nil)
      expect(key).to eq("_global")
    end

    it "builds key from virtual year" do
      key = LcpRuby::Sequences.build_scope_key({ "_year" => "2026" })
      expect(key).to eq("_year:2026")
    end

    it "builds compound key" do
      key = LcpRuby::Sequences.build_scope_key({ "department_id" => "5", "_year" => "2026" })
      expect(key).to eq("department_id:5/_year:2026")
    end
  end

  describe ".format_value" do
    it "handles zero-padded sequence" do
      result = described_class.format_value(42, "TKT-%{sequence:06d}", double, {})
      expect(result).to eq("TKT-000042")
    end

    it "handles raw sequence" do
      result = described_class.format_value(42, "NUM-%{sequence}", double, {})
      expect(result).to eq("NUM-42")
    end

    it "handles scope values" do
      result = described_class.format_value(1, "INV-%{_year}-%{sequence:04d}", double, { "_year" => "2026" })
      expect(result).to eq("INV-2026-0001")
    end

    it "handles field references" do
      record = double(dept_code: "HR")
      allow(record).to receive(:respond_to?).with("dept_code").and_return(true)
      result = described_class.format_value(5, "%{dept_code}-%{sequence:03d}", record, {})
      expect(result).to eq("HR-005")
    end
  end
end
