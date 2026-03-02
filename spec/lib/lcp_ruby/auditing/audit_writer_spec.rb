require "spec_helper"

RSpec.describe LcpRuby::Auditing::AuditWriter do
  let(:model_def) do
    LcpRuby::Metadata::ModelDefinition.from_hash({
      "name" => "test_record",
      "fields" => [
        { "name" => "title", "type" => "string" },
        { "name" => "amount", "type" => "integer" },
        { "name" => "config_data", "type" => "json" },
        { "name" => "custom_data", "type" => "json" }
      ],
      "options" => { "timestamps" => true, "auditing" => true }
    })
  end

  let(:default_options) { {} }

  # Stub record that behaves like an AR model
  def make_record(attrs: {}, saved_changes: {})
    record = double("record")
    allow(record).to receive(:attributes).and_return(attrs.stringify_keys)
    allow(record).to receive(:saved_changes).and_return(saved_changes.stringify_keys)
    allow(record).to receive(:id).and_return(attrs[:id] || attrs["id"] || 1)
    record
  end

  describe "compute_scalar_changes (private)" do
    context "for create action" do
      it "returns all fields as [nil, value] pairs" do
        record = make_record(attrs: { title: "Foo", amount: 100, id: 1 })
        changes = described_class.send(:compute_scalar_changes, :create, record)

        expect(changes["title"]).to eq([nil, "Foo"])
        expect(changes["amount"]).to eq([nil, 100])
        expect(changes).not_to have_key("id")
        expect(changes).not_to have_key("created_at")
        expect(changes).not_to have_key("updated_at")
      end
    end

    context "for update action" do
      it "returns only changed fields from saved_changes" do
        record = make_record(saved_changes: {
          "title" => ["Old", "New"],
          "updated_at" => [Time.now - 1, Time.now]
        })

        changes = described_class.send(:compute_scalar_changes, :update, record)
        expect(changes["title"]).to eq(["Old", "New"])
        expect(changes).not_to have_key("updated_at")
      end
    end

    context "for destroy action" do
      it "returns all fields as [value, nil] pairs" do
        record = make_record(attrs: { title: "Foo", amount: 100, id: 1 })
        changes = described_class.send(:compute_scalar_changes, :destroy, record)

        expect(changes["title"]).to eq(["Foo", nil])
        expect(changes["amount"]).to eq([100, nil])
      end
    end

    context "for discard/undiscard action" do
      it "returns empty hash (update_columns bypasses dirty tracking)" do
        record = make_record(saved_changes: { "discarded_at" => [nil, Time.now] })

        expect(described_class.send(:compute_scalar_changes, :discard, record)).to eq({})
        expect(described_class.send(:compute_scalar_changes, :undiscard, record)).to eq({})
      end
    end
  end

  describe "filter_fields (private)" do
    it "excludes EXCLUDED_FIELDS" do
      changes = { "id" => [nil, 1], "created_at" => [nil, Time.now], "title" => [nil, "Foo"] }
      result = described_class.send(:filter_fields, changes, default_options, model_def)
      expect(result.keys).to eq(["title"])
    end

    it "applies only filter" do
      changes = { "title" => [nil, "Foo"], "amount" => [nil, 100] }
      result = described_class.send(:filter_fields, changes, { "only" => ["title"] }, model_def)
      expect(result.keys).to eq(["title"])
    end

    it "applies ignore filter" do
      changes = { "title" => [nil, "Foo"], "amount" => [nil, 100] }
      result = described_class.send(:filter_fields, changes, { "ignore" => ["amount"] }, model_def)
      expect(result.keys).to eq(["title"])
    end
  end

  describe "expand_custom_data! (private)" do
    it "expands custom_data into cf: prefixed keys" do
      changes = {
        "title" => [nil, "Foo"],
        "custom_data" => [
          { "risk" => 30, "priority" => "low" },
          { "risk" => 80, "priority" => "high" }
        ]
      }

      described_class.send(:expand_custom_data!, changes)
      expect(changes).not_to have_key("custom_data")
      expect(changes["cf:risk"]).to eq([30, 80])
      expect(changes["cf:priority"]).to eq(["low", "high"])
      expect(changes["title"]).to eq([nil, "Foo"])
    end

    it "handles nil old value" do
      changes = {
        "custom_data" => [nil, { "field1" => "value1" }]
      }

      described_class.send(:expand_custom_data!, changes)
      expect(changes["cf:field1"]).to eq([nil, "value1"])
    end

    it "skips keys where values are equal" do
      changes = {
        "custom_data" => [
          { "same" => "value", "changed" => "old" },
          { "same" => "value", "changed" => "new" }
        ]
      }

      described_class.send(:expand_custom_data!, changes)
      expect(changes).not_to have_key("cf:same")
      expect(changes["cf:changed"]).to eq(["old", "new"])
    end
  end

  describe "expand_json_field! (private)" do
    it "expands hash values into dot-path diffs" do
      changes = {
        "config_data" => [
          { "notify" => false, "retries" => 3 },
          { "notify" => true, "retries" => 5 }
        ]
      }

      described_class.send(:expand_json_field!, changes, "config_data")
      expect(changes).not_to have_key("config_data")
      expect(changes["config_data.notify"]).to eq([false, true])
      expect(changes["config_data.retries"]).to eq([3, 5])
    end

    it "stores array values as whole-value diff" do
      changes = {
        "config_data" => [
          ["a", "b"],
          ["a", "b", "c"]
        ]
      }

      described_class.send(:expand_json_field!, changes, "config_data")
      expect(changes["config_data"]).to eq([["a", "b"], ["a", "b", "c"]])
    end

    it "handles nil to hash transition" do
      changes = {
        "config_data" => [nil, { "key" => "value" }]
      }

      described_class.send(:expand_json_field!, changes, "config_data")
      # nil is not a Hash, so it's stored as whole-value
      expect(changes["config_data"]).to eq([nil, { "key" => "value" }])
    end
  end

  describe ".log" do
    it "delegates to custom audit_writer when configured" do
      custom_writer = double("custom_writer")
      allow(LcpRuby.configuration).to receive(:audit_writer).and_return(custom_writer)

      record = make_record(attrs: { title: "Foo", id: 1 })

      expect(custom_writer).to receive(:log).with(
        action: :create,
        record: record,
        changes: a_kind_of(Hash),
        user: anything,
        metadata: anything
      )

      described_class.log(
        action: :create,
        record: record,
        options: default_options,
        model_definition: model_def
      )
    end
  end
end
