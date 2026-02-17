require "spec_helper"

# Pipeline integration tests: DSL/YAML → ModelDefinition → Builder.build → AR model → behavior
#
# These tests exercise the full vertical from definition to runtime behavior,
# catching bugs at layer boundaries that unit tests miss.
RSpec.describe "Model build pipeline" do
  before do
    LcpRuby::Types::BuiltInServices.register_all!
    LcpRuby::Types::BuiltInTypes.register_all!
    LcpRuby::Services::BuiltInTransforms.register_all!
    LcpRuby::Services::BuiltInDefaults.register_all!
  end

  after do
    conn = ActiveRecord::Base.connection
    %i[pipeline_tests pipeline_parents pipeline_children].each do |table|
      conn.drop_table(table) if conn.table_exists?(table)
    end
  end

  # Build a model from a DSL block through the full pipeline:
  # DSL → to_hash → ModelDefinition → SchemaManager → Builder.build
  def build_from_dsl(&block)
    definition = LcpRuby.define_model(:pipeline_test, &block)
    LcpRuby::ModelFactory::SchemaManager.new(definition).ensure_table!
    LcpRuby::ModelFactory::Builder.new(definition).build
  end

  # Build a model from a YAML-style hash through the full pipeline:
  # Hash → ModelDefinition → SchemaManager → Builder.build
  def build_from_hash(model_hash)
    definition = LcpRuby::Metadata::ModelDefinition.from_hash(model_hash)
    LcpRuby::ModelFactory::SchemaManager.new(definition).ensure_table!
    LcpRuby::ModelFactory::Builder.new(definition).build
  end

  describe "FK field validation via DSL" do
    it "applies conditional validation on belongs_to FK field" do
      model_class = build_from_dsl do
        field :title, :string
        field :stage, :enum, values: %w[lead negotiation closed]
        belongs_to :contact, class_name: "Contact", required: false
        validates :contact_id, :presence, when: { field: :stage, operator: :in, value: %w[negotiation closed] }
        timestamps false
      end

      record = model_class.new(title: "Deal A", stage: "lead", contact_id: nil)
      expect(record).to be_valid

      record.stage = "negotiation"
      expect(record).not_to be_valid
      expect(record.errors[:contact_id]).to include("can't be blank")

      record.contact_id = 1
      expect(record).to be_valid
    end

    it "applies validation on FK field with explicit foreign_key" do
      model_class = build_from_dsl do
        field :title, :string
        belongs_to :author, class_name: "User", foreign_key: :author_id, required: false
        validates :author_id, :presence
        timestamps false
      end

      record = model_class.new(title: "Test", author_id: nil)
      expect(record).not_to be_valid
      expect(record.errors[:author_id]).to include("can't be blank")

      record.author_id = 1
      expect(record).to be_valid
    end
  end

  describe "discovered transform services" do
    before do
      fixture_path = File.expand_path("../../../fixtures/services", __dir__)
      LcpRuby::Services::Registry.discover!(fixture_path)
    end

    it "applies discovered transform to field values" do
      model_class = build_from_dsl do
        field :name, :string, transforms: [:upcase]
        timestamps false
      end

      record = model_class.new(name: "hello world")
      expect(record.name).to eq("HELLO WORLD")
    end

    it "combines discovered transform with built-in transforms" do
      model_class = build_from_dsl do
        field :name, :string, transforms: [:strip, :upcase]
        timestamps false
      end

      record = model_class.new(name: "  hello  ")
      expect(record.name).to eq("HELLO")
    end
  end

  describe "field-level transforms via DSL" do
    it "applies built-in transforms defined in DSL" do
      model_class = build_from_dsl do
        field :email, :string, transforms: [:strip, :downcase]
        timestamps false
      end

      record = model_class.new(email: "  FOO@BAR.COM  ")
      expect(record.email).to eq("foo@bar.com")
    end
  end

  describe "conditional validation via DSL" do
    it "applies when: condition on field validation" do
      model_class = build_from_dsl do
        field :completed, :boolean, default: false
        field :due_date, :date do
          validates :presence, when: { field: :completed, operator: :eq, value: false }
        end
        timestamps false
      end

      record = model_class.new(completed: false, due_date: nil)
      expect(record).not_to be_valid
      expect(record.errors[:due_date]).to include("can't be blank")

      record.completed = true
      expect(record).to be_valid
    end
  end

  describe "comparison validation via DSL" do
    it "validates cross-field comparison" do
      model_class = build_from_dsl do
        field :start_date, :date
        field :end_date, :date do
          validates :comparison, operator: :gte, field_ref: :start_date,
            message: "must be on or after start date"
        end
        timestamps false
      end

      record = model_class.new(start_date: Date.new(2025, 6, 1), end_date: Date.new(2025, 5, 1))
      expect(record).not_to be_valid
      expect(record.errors[:end_date]).to include("must be on or after start date")

      record.end_date = Date.new(2025, 7, 1)
      expect(record).to be_valid
    end
  end

  describe "service validation via DSL" do
    it "applies field-level service validator" do
      validator = Class.new do
        def self.call(record, **opts)
          value = record.send(opts[:field])
          if value.to_s.include?("forbidden")
            record.errors.add(opts[:field], "contains forbidden content")
          end
        end
      end
      LcpRuby::Services::Registry.register("validators", "content_checker", validator)

      model_class = build_from_dsl do
        field :title, :string do
          validates :service, service: :content_checker
        end
        timestamps false
      end

      record = model_class.new(title: "this is forbidden content")
      expect(record).not_to be_valid
      expect(record.errors[:title]).to include("contains forbidden content")

      record.title = "this is fine"
      expect(record).to be_valid
    end

    it "applies model-level service validator via validates_model" do
      validator = Class.new do
        def self.call(record, **_opts)
          if record.start_date && record.end_date && record.end_date < record.start_date
            record.errors.add(:base, "end date must be after start date")
          end
        end
      end
      LcpRuby::Services::Registry.register("validators", "date_range_check", validator)

      model_class = build_from_dsl do
        field :start_date, :date
        field :end_date, :date
        validates_model :service, service: :date_range_check
        timestamps false
      end

      record = model_class.new(start_date: Date.new(2025, 6, 1), end_date: Date.new(2025, 5, 1))
      expect(record).not_to be_valid
      expect(record.errors[:base]).to include("end date must be after start date")
    end
  end

  describe "dynamic defaults via DSL" do
    it "applies built-in default (current_date)" do
      model_class = build_from_dsl do
        field :title, :string
        field :created_on, :date, default: "current_date"
        timestamps false
      end

      record = model_class.new(title: "Test")
      expect(record.created_on).to eq(Date.current)
    end

    it "applies service-based default" do
      default_service = Class.new do
        def self.call(_record, _field_name)
          Date.current + 7
        end
      end
      LcpRuby::Services::Registry.register("defaults", "one_week_out", default_service)

      model_class = build_from_dsl do
        field :title, :string
        field :due_date, :date, default: { service: "one_week_out" }
        timestamps false
      end

      record = model_class.new(title: "Test")
      expect(record.due_date).to eq(Date.current + 7)
    end

    it "does not overwrite explicitly set values" do
      model_class = build_from_dsl do
        field :title, :string
        field :created_on, :date, default: "current_date"
        timestamps false
      end

      explicit_date = Date.new(2020, 1, 1)
      record = model_class.new(title: "Test", created_on: explicit_date)
      expect(record.created_on).to eq(explicit_date)
    end
  end

  describe "computed fields via DSL" do
    it "computes template-based field on save" do
      model_class = build_from_dsl do
        field :first_name, :string
        field :last_name, :string
        field :full_name, :string, computed: "{first_name} {last_name}"
        timestamps false
      end

      record = model_class.new(first_name: "John", last_name: "Doe")
      # before_save hasn't fired yet
      expect(record.full_name).to be_nil

      record.save!
      expect(record.full_name).to eq("John Doe")
    end

    it "computes service-based field on save" do
      computed_service = Class.new do
        def self.call(record)
          price = record.price.to_f
          quantity = record.quantity.to_i
          (price * quantity).round(2)
        end
      end
      LcpRuby::Services::Registry.register("computed", "line_total", computed_service)

      model_class = build_from_dsl do
        field :price, :decimal, precision: 10, scale: 2
        field :quantity, :integer
        field :total, :decimal, precision: 10, scale: 2, computed: { service: "line_total" }
        timestamps false
      end

      record = model_class.new(price: 19.99, quantity: 3)
      record.save!
      expect(record.total).to eq(59.97)
    end
  end

  describe "enums via DSL" do
    it "defines enum with value accessors and query methods" do
      model_class = build_from_dsl do
        field :status, :enum, default: "draft", values: { draft: "Draft", active: "Active", archived: "Archived" }
        timestamps false
      end

      record = model_class.new
      expect(record.status).to eq("draft")

      record.status = "active"
      expect(record.status).to eq("active")

      expect(model_class.statuses).to eq({ "draft" => "draft", "active" => "active", "archived" => "archived" })
    end

    it "supports enum scopes" do
      model_class = build_from_dsl do
        field :title, :string
        field :status, :enum, default: "draft", values: %w[draft active archived]
        timestamps false
      end

      model_class.create!(title: "A", status: "draft")
      model_class.create!(title: "B", status: "active")
      model_class.create!(title: "C", status: "active")

      expect(model_class.active.count).to eq(2)
      expect(model_class.draft.count).to eq(1)
    end
  end

  describe "standard validations via DSL" do
    it "applies presence validation" do
      model_class = build_from_dsl do
        field :title, :string do
          validates :presence
        end
        timestamps false
      end

      record = model_class.new(title: nil)
      expect(record).not_to be_valid
      expect(record.errors[:title]).to include("can't be blank")

      record.title = "Hello"
      expect(record).to be_valid
    end

    it "applies length validation" do
      model_class = build_from_dsl do
        field :title, :string do
          validates :length, minimum: 3, maximum: 10
        end
        timestamps false
      end

      record = model_class.new(title: "Hi")
      expect(record).not_to be_valid

      record.title = "Hello"
      expect(record).to be_valid

      record.title = "This is way too long"
      expect(record).not_to be_valid
    end

    it "applies numericality validation" do
      model_class = build_from_dsl do
        field :score, :integer do
          validates :numericality, greater_than_or_equal_to: 0, less_than_or_equal_to: 100
        end
        timestamps false
      end

      record = model_class.new(score: -1)
      expect(record).not_to be_valid

      record.score = 50
      expect(record).to be_valid

      record.score = 101
      expect(record).not_to be_valid
    end

    it "applies format validation" do
      model_class = build_from_dsl do
        field :code, :string do
          validates :format, with: '\A[A-Z]{3}-\d{3}\z', message: "must be like ABC-123"
        end
        timestamps false
      end

      record = model_class.new(code: "invalid")
      expect(record).not_to be_valid
      expect(record.errors[:code]).to include("must be like ABC-123")

      record.code = "ABC-123"
      expect(record).to be_valid
    end

    it "applies inclusion validation" do
      model_class = build_from_dsl do
        field :priority, :string do
          validates :inclusion, in: %w[low medium high]
        end
        timestamps false
      end

      record = model_class.new(priority: "urgent")
      expect(record).not_to be_valid

      record.priority = "high"
      expect(record).to be_valid
    end

    it "combines multiple validations on one field" do
      model_class = build_from_dsl do
        field :title, :string do
          validates :presence
          validates :length, minimum: 3, maximum: 50
        end
        timestamps false
      end

      record = model_class.new(title: nil)
      expect(record).not_to be_valid
      expect(record.errors[:title]).to include("can't be blank")

      record.title = "Hi"
      expect(record).not_to be_valid
      expect(record.errors[:title].any? { |e| e.include?("too short") }).to be true

      record.title = "Hello World"
      expect(record).to be_valid
    end
  end

  describe "associations via DSL" do
    # Helper to build two related models for association tests
    def build_parent_and_child
      parent_def = LcpRuby::Metadata::ModelDefinition.from_hash(
        "name" => "pipeline_parent",
        "fields" => [
          { "name" => "title", "type" => "string" }
        ],
        "associations" => [
          { "type" => "has_many", "name" => "pipeline_children", "target_model" => "pipeline_child", "dependent" => "destroy" }
        ],
        "options" => { "timestamps" => false }
      )

      child_def = LcpRuby::Metadata::ModelDefinition.from_hash(
        "name" => "pipeline_child",
        "fields" => [
          { "name" => "name", "type" => "string" }
        ],
        "associations" => [
          { "type" => "belongs_to", "name" => "pipeline_parent", "target_model" => "pipeline_parent" }
        ],
        "options" => { "timestamps" => false }
      )

      LcpRuby::ModelFactory::SchemaManager.new(parent_def).ensure_table!
      LcpRuby::ModelFactory::SchemaManager.new(child_def).ensure_table!

      parent_class = LcpRuby::ModelFactory::Builder.new(parent_def).build
      child_class = LcpRuby::ModelFactory::Builder.new(child_def).build

      LcpRuby.registry.register("pipeline_parent", parent_class)
      LcpRuby.registry.register("pipeline_child", child_class)

      [parent_class, child_class]
    end

    it "creates working belongs_to and has_many associations" do
      parent_class, child_class = build_parent_and_child

      parent = parent_class.create!(title: "Parent")
      child = child_class.create!(name: "Child", pipeline_parent: parent)

      expect(child.pipeline_parent).to eq(parent)
      expect(parent.pipeline_children).to include(child)
      expect(parent.pipeline_children.count).to eq(1)
    end

    it "applies dependent: :destroy on has_many" do
      parent_class, child_class = build_parent_and_child

      parent = parent_class.create!(title: "Parent")
      child_class.create!(name: "Child 1", pipeline_parent: parent)
      child_class.create!(name: "Child 2", pipeline_parent: parent)

      expect(child_class.count).to eq(2)
      parent.destroy!
      expect(child_class.count).to eq(0)
    end

    it "enforces required belongs_to by default" do
      _parent_class, child_class = build_parent_and_child

      record = child_class.new(name: "Orphan", pipeline_parent_id: nil)
      expect(record).not_to be_valid
      expect(record.errors[:pipeline_parent]).to be_present
    end

    it "allows optional belongs_to when required: false" do
      parent_def = LcpRuby::Metadata::ModelDefinition.from_hash(
        "name" => "pipeline_parent",
        "fields" => [{ "name" => "title", "type" => "string" }],
        "options" => { "timestamps" => false }
      )

      child_def = LcpRuby::Metadata::ModelDefinition.from_hash(
        "name" => "pipeline_child",
        "fields" => [{ "name" => "name", "type" => "string" }],
        "associations" => [
          { "type" => "belongs_to", "name" => "pipeline_parent", "target_model" => "pipeline_parent", "required" => false }
        ],
        "options" => { "timestamps" => false }
      )

      LcpRuby::ModelFactory::SchemaManager.new(parent_def).ensure_table!
      LcpRuby::ModelFactory::SchemaManager.new(child_def).ensure_table!

      LcpRuby::ModelFactory::Builder.new(parent_def).build
      child_class = LcpRuby::ModelFactory::Builder.new(child_def).build

      record = child_class.new(name: "Orphan", pipeline_parent_id: nil)
      expect(record).to be_valid
    end
  end

  describe "scopes via DSL" do
    it "filters records with where scope" do
      model_class = build_from_dsl do
        field :title, :string
        field :status, :string
        scope :active, where: { status: "active" }
        scope :draft, where: { status: "draft" }
        timestamps false
      end

      model_class.create!(title: "A", status: "active")
      model_class.create!(title: "B", status: "active")
      model_class.create!(title: "C", status: "draft")

      expect(model_class.active.count).to eq(2)
      expect(model_class.draft.count).to eq(1)
    end

    it "filters records with where_not scope" do
      model_class = build_from_dsl do
        field :title, :string
        field :status, :string
        scope :not_archived, where_not: { status: "archived" }
        timestamps false
      end

      model_class.create!(title: "A", status: "active")
      model_class.create!(title: "B", status: "archived")

      expect(model_class.not_archived.count).to eq(1)
      expect(model_class.not_archived.first.title).to eq("A")
    end

    it "applies order and limit" do
      model_class = build_from_dsl do
        field :title, :string
        field :priority, :integer
        scope :top3, order: { priority: :desc }, limit: 3
        timestamps false
      end

      5.times { |i| model_class.create!(title: "Item #{i}", priority: i) }

      result = model_class.top3
      expect(result.count).to eq(3)
      expect(result.map(&:priority)).to eq([4, 3, 2])
    end
  end

  describe "label_method via DSL" do
    it "defines to_label method on model" do
      model_class = build_from_dsl do
        field :title, :string
        field :code, :string
        label_method :code
        timestamps false
      end

      record = model_class.new(title: "My Project", code: "PRJ-001")
      expect(record.to_label).to eq("PRJ-001")
    end
  end

  describe "type-level transforms via DSL" do
    it "applies transforms from custom type through field type" do
      model_class = build_from_dsl do
        field :contact_email, :email
        timestamps false
      end

      record = model_class.new(contact_email: "  FOO@BAR.COM  ")
      expect(record.contact_email).to eq("foo@bar.com")
    end
  end

  describe "combined features via YAML hash" do
    it "builds model with transforms + conditional validation + comparison + defaults" do
      model_class = build_from_hash(
        "name" => "pipeline_test",
        "fields" => [
          { "name" => "title", "type" => "string", "transforms" => ["strip"] },
          { "name" => "active", "type" => "boolean", "default" => true },
          { "name" => "start_date", "type" => "date", "default" => "current_date" },
          {
            "name" => "end_date",
            "type" => "date",
            "validations" => [
              {
                "type" => "comparison",
                "operator" => "gte",
                "field_ref" => "start_date",
                "message" => "must be on or after start date",
                "when" => { "field" => "active", "operator" => "eq", "value" => "true" }
              }
            ]
          }
        ],
        "options" => { "timestamps" => false }
      )

      # Transform: strip
      record = model_class.new(title: "  Hello  ")
      expect(record.title).to eq("Hello")

      # Default: current_date
      record = model_class.new(title: "Test")
      expect(record.start_date).to eq(Date.current)

      # Comparison + when: active=true, end_date < start_date → invalid
      record = model_class.new(
        title: "Test", active: true,
        start_date: Date.new(2025, 6, 1), end_date: Date.new(2025, 5, 1)
      )
      expect(record).not_to be_valid
      expect(record.errors[:end_date]).to include("must be on or after start date")

      # Comparison skipped when: active=false
      record.active = false
      expect(record).to be_valid
    end
  end
end
