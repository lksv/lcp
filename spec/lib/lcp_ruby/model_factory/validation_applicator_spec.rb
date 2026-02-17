require "spec_helper"

RSpec.describe LcpRuby::ModelFactory::ValidationApplicator do
  before do
    LcpRuby::Types::BuiltInServices.register_all!
    LcpRuby::Types::BuiltInTypes.register_all!
    LcpRuby::Services::BuiltInTransforms.register_all!
    LcpRuby::Services::BuiltInDefaults.register_all!
  end

  after do
    ActiveRecord::Base.connection.drop_table(:tasks) if ActiveRecord::Base.connection.table_exists?(:tasks)
  end

  def build_model(model_hash)
    model_definition = LcpRuby::Metadata::ModelDefinition.from_hash(model_hash)
    LcpRuby::ModelFactory::SchemaManager.new(model_definition).ensure_table!

    model_class = Class.new(ActiveRecord::Base) do
      self.table_name = model_definition.table_name
    end
    LcpRuby::Dynamic.const_set(:Task, model_class)

    described_class.new(model_class, model_definition).apply!
    model_class
  end

  describe "conditional validations with when:" do
    let(:model_hash) do
      {
        "name" => "task",
        "fields" => [
          { "name" => "title", "type" => "string" },
          { "name" => "completed", "type" => "boolean", "default" => false },
          {
            "name" => "due_date",
            "type" => "date",
            "validations" => [
              {
                "type" => "presence",
                "when" => { "field" => "completed", "operator" => "eq", "value" => "false" }
              }
            ]
          }
        ],
        "options" => { "timestamps" => false }
      }
    end

    it "validates when condition is met" do
      model_class = build_model(model_hash)
      record = model_class.new(title: "Test", completed: false, due_date: nil)
      expect(record).not_to be_valid
      expect(record.errors[:due_date]).to include("can't be blank")
    end

    it "skips validation when condition is not met" do
      model_class = build_model(model_hash)
      record = model_class.new(title: "Test", completed: true, due_date: nil)
      expect(record).to be_valid
    end

    it "validates successfully when condition is met and value is present" do
      model_class = build_model(model_hash)
      record = model_class.new(title: "Test", completed: false, due_date: Date.today)
      expect(record).to be_valid
    end
  end

  describe "conditional validation with service condition" do
    let(:model_hash) do
      {
        "name" => "task",
        "fields" => [
          { "name" => "title", "type" => "string" },
          { "name" => "priority", "type" => "integer" },
          {
            "name" => "description",
            "type" => "text",
            "validations" => [
              {
                "type" => "presence",
                "when" => { "service" => "high_priority_check" }
              }
            ]
          }
        ],
        "options" => { "timestamps" => false }
      }
    end

    it "evaluates service condition for validation" do
      service = ->(record) { record.priority.to_i > 5 }
      LcpRuby::ConditionServiceRegistry.register("high_priority_check", service)

      model_class = build_model(model_hash)

      high_priority = model_class.new(title: "Test", priority: 10, description: nil)
      expect(high_priority).not_to be_valid
      expect(high_priority.errors[:description]).to include("can't be blank")

      low_priority = model_class.new(title: "Test", priority: 2, description: nil)
      expect(low_priority).to be_valid
    end
  end

  describe "comparison validation" do
    let(:model_hash) do
      {
        "name" => "task",
        "fields" => [
          { "name" => "title", "type" => "string" },
          { "name" => "start_date", "type" => "date" },
          {
            "name" => "due_date",
            "type" => "date",
            "validations" => [
              {
                "type" => "comparison",
                "operator" => "gte",
                "field_ref" => "start_date",
                "message" => "must be on or after start date"
              }
            ]
          }
        ],
        "options" => { "timestamps" => false }
      }
    end

    it "fails when due_date is before start_date" do
      model_class = build_model(model_hash)
      record = model_class.new(title: "Test", start_date: Date.today, due_date: Date.today - 1)
      expect(record).not_to be_valid
      expect(record.errors[:due_date]).to include("must be on or after start date")
    end

    it "passes when due_date is on or after start_date" do
      model_class = build_model(model_hash)
      record = model_class.new(title: "Test", start_date: Date.today, due_date: Date.today + 1)
      expect(record).to be_valid
    end

    it "skips comparison when either value is nil" do
      model_class = build_model(model_hash)
      record = model_class.new(title: "Test", start_date: nil, due_date: Date.today)
      expect(record).to be_valid

      record2 = model_class.new(title: "Test", start_date: Date.today, due_date: nil)
      expect(record2).to be_valid
    end

    it "supports gt operator" do
      hash = model_hash.dup
      hash["fields"] = hash["fields"].map(&:dup)
      hash["fields"][2] = hash["fields"][2].merge(
        "validations" => [{ "type" => "comparison", "operator" => "gt", "field_ref" => "start_date" }]
      )

      model_class = build_model(hash)

      # Equal dates should fail with gt
      record = model_class.new(title: "Test", start_date: Date.today, due_date: Date.today)
      expect(record).not_to be_valid

      # Later date should pass
      record2 = model_class.new(title: "Test", start_date: Date.today, due_date: Date.today + 1)
      expect(record2).to be_valid
    end
  end

  describe "comparison validation with when: condition" do
    let(:model_hash) do
      {
        "name" => "task",
        "fields" => [
          { "name" => "title", "type" => "string" },
          { "name" => "active", "type" => "boolean", "default" => true },
          { "name" => "start_date", "type" => "date" },
          {
            "name" => "due_date",
            "type" => "date",
            "validations" => [
              {
                "type" => "comparison",
                "operator" => "gte",
                "field_ref" => "start_date",
                "when" => { "field" => "active", "operator" => "eq", "value" => "true" }
              }
            ]
          }
        ],
        "options" => { "timestamps" => false }
      }
    end

    it "skips comparison when when: condition is not met" do
      model_class = build_model(model_hash)
      record = model_class.new(title: "Test", active: false, start_date: Date.today, due_date: Date.today - 5)
      expect(record).to be_valid
    end

    it "applies comparison when when: condition is met" do
      model_class = build_model(model_hash)
      record = model_class.new(title: "Test", active: true, start_date: Date.today, due_date: Date.today - 5)
      expect(record).not_to be_valid
    end
  end

  describe "service validation" do
    let(:model_hash) do
      {
        "name" => "task",
        "fields" => [
          { "name" => "title", "type" => "string" },
          { "name" => "priority", "type" => "integer" },
          {
            "name" => "description",
            "type" => "text",
            "validations" => [
              {
                "type" => "service",
                "service" => "description_checker"
              }
            ]
          }
        ],
        "options" => { "timestamps" => false }
      }
    end

    it "calls service validator" do
      checker = Class.new do
        def self.call(record, **opts)
          if record.description.to_s.length < 5
            record.errors.add(opts[:field], "must be at least 5 characters")
          end
        end
      end
      LcpRuby::Services::Registry.register("validators", "description_checker", checker)

      model_class = build_model(model_hash)

      record = model_class.new(title: "Test", description: "Hi")
      expect(record).not_to be_valid
      expect(record.errors[:description]).to include("must be at least 5 characters")

      record2 = model_class.new(title: "Test", description: "Hello World")
      expect(record2).to be_valid
    end
  end

  describe "model-level service validation" do
    let(:model_hash) do
      {
        "name" => "task",
        "fields" => [
          { "name" => "title", "type" => "string" },
          { "name" => "priority", "type" => "integer" }
        ],
        "validations" => [
          { "type" => "service", "service" => "task_consistency" }
        ],
        "options" => { "timestamps" => false }
      }
    end

    it "calls model-level service validator" do
      checker = Class.new do
        def self.call(record, **opts)
          if record.title.to_s.blank? && record.priority.to_i > 5
            record.errors.add(:base, "high priority tasks must have a title")
          end
        end
      end
      LcpRuby::Services::Registry.register("validators", "task_consistency", checker)

      model_class = build_model(model_hash)

      record = model_class.new(title: nil, priority: 10)
      expect(record).not_to be_valid
      expect(record.errors[:base]).to include("high priority tasks must have a title")

      record2 = model_class.new(title: "Important", priority: 10)
      expect(record2).to be_valid
    end
  end
end
