require "spec_helper"

RSpec.describe LcpRuby::Dsl::ModelBuilder do
  describe "#to_hash" do
    it "produces a hash with the model name" do
      builder = described_class.new(:project)
      hash = builder.to_hash

      expect(hash["name"]).to eq("project")
    end

    it "includes label and label_plural when set" do
      builder = described_class.new(:deal)
      builder.instance_eval do
        label "Deal"
        label_plural "Deals"
      end
      hash = builder.to_hash

      expect(hash["label"]).to eq("Deal")
      expect(hash["label_plural"]).to eq("Deals")
    end

    it "omits label keys when not set" do
      builder = described_class.new(:deal)
      hash = builder.to_hash

      expect(hash).not_to have_key("label")
      expect(hash).not_to have_key("label_plural")
    end

    it "includes table_name when set" do
      builder = described_class.new(:deal)
      builder.instance_eval { table_name "custom_deals" }
      hash = builder.to_hash

      expect(hash["table_name"]).to eq("custom_deals")
    end
  end

  describe "fields" do
    it "produces a field hash with name and type" do
      builder = described_class.new(:project)
      builder.instance_eval do
        field :title, :string
      end
      hash = builder.to_hash

      expect(hash["fields"].length).to eq(1)
      field = hash["fields"].first
      expect(field["name"]).to eq("title")
      expect(field["type"]).to eq("string")
    end

    it "includes label when provided" do
      builder = described_class.new(:project)
      builder.instance_eval do
        field :title, :string, label: "Title"
      end

      field = builder.to_hash["fields"].first
      expect(field["label"]).to eq("Title")
    end

    it "includes default when provided" do
      builder = described_class.new(:project)
      builder.instance_eval do
        field :completed, :boolean, default: false
      end

      field = builder.to_hash["fields"].first
      expect(field["default"]).to eq(false)
    end

    it "extracts column_options from top-level kwargs" do
      builder = described_class.new(:project)
      builder.instance_eval do
        field :budget, :decimal, precision: 12, scale: 2
      end

      field = builder.to_hash["fields"].first
      expect(field["column_options"]).to eq({ "precision" => 12, "scale" => 2 })
    end

    it "handles limit and null column options" do
      builder = described_class.new(:project)
      builder.instance_eval do
        field :title, :string, limit: 255, null: false
      end

      field = builder.to_hash["fields"].first
      expect(field["column_options"]).to eq({ "limit" => 255, "null" => false })
    end

    it "omits column_options when none provided" do
      builder = described_class.new(:project)
      builder.instance_eval do
        field :title, :string
      end

      field = builder.to_hash["fields"].first
      expect(field).not_to have_key("column_options")
    end
  end

  describe "empty hash omissions" do
    it "omits fields key when no fields defined" do
      builder = described_class.new(:project)
      hash = builder.to_hash

      expect(hash).not_to have_key("fields")
    end

    it "omits associations key when no associations defined" do
      builder = described_class.new(:project)
      hash = builder.to_hash

      expect(hash).not_to have_key("associations")
    end

    it "omits scopes key when no scopes defined" do
      builder = described_class.new(:project)
      hash = builder.to_hash

      expect(hash).not_to have_key("scopes")
    end

    it "omits events key when no events defined" do
      builder = described_class.new(:project)
      hash = builder.to_hash

      expect(hash).not_to have_key("events")
    end

    it "omits options key when no options set" do
      builder = described_class.new(:project)
      hash = builder.to_hash

      expect(hash).not_to have_key("options")
    end
  end

  describe "enum fields" do
    it "normalizes hash values to enum_values array" do
      builder = described_class.new(:project)
      builder.instance_eval do
        field :status, :enum, values: { draft: "Draft", active: "Active" }
      end

      field = builder.to_hash["fields"].first
      expect(field["enum_values"]).to eq([
        { "value" => "draft", "label" => "Draft" },
        { "value" => "active", "label" => "Active" }
      ])
    end

    it "auto-humanizes array values" do
      builder = described_class.new(:project)
      builder.instance_eval do
        field :priority, :enum, values: [ :low, :medium, :high ]
      end

      field = builder.to_hash["fields"].first
      expect(field["enum_values"]).to eq([
        { "value" => "low", "label" => "Low" },
        { "value" => "medium", "label" => "Medium" },
        { "value" => "high", "label" => "High" }
      ])
    end

    it "includes default for enum fields" do
      builder = described_class.new(:project)
      builder.instance_eval do
        field :status, :enum, default: "draft", values: { draft: "Draft" }
      end

      field = builder.to_hash["fields"].first
      expect(field["default"]).to eq("draft")
    end

    it "raises MetadataError for invalid enum values format" do
      builder = described_class.new(:project)

      expect {
        builder.instance_eval do
          field :status, :enum, values: "invalid"
        end
      }.to raise_error(LcpRuby::MetadataError, /Invalid enum values format/)
    end
  end

  describe "field-level validations (Style A)" do
    it "collects validations from field block" do
      builder = described_class.new(:project)
      builder.instance_eval do
        field :title, :string do
          validates :presence
          validates :length, minimum: 3, maximum: 255
        end
      end

      field = builder.to_hash["fields"].first
      expect(field["validations"].length).to eq(2)
      expect(field["validations"][0]).to eq({ "type" => "presence" })
      expect(field["validations"][1]).to eq({
        "type" => "length",
        "options" => { "minimum" => 3, "maximum" => 255 }
      })
    end

    it "handles numericality validation with options" do
      builder = described_class.new(:project)
      builder.instance_eval do
        field :budget, :decimal do
          validates :numericality, greater_than_or_equal_to: 0, allow_nil: true
        end
      end

      field = builder.to_hash["fields"].first
      validation = field["validations"].first
      expect(validation["type"]).to eq("numericality")
      expect(validation["options"]).to eq({
        "greater_than_or_equal_to" => 0,
        "allow_nil" => true
      })
    end

    it "handles format validation with pattern" do
      builder = described_class.new(:contact)
      builder.instance_eval do
        field :email, :string do
          validates :format, with: '\A[^@\s]+@[^@\s]+\z', allow_blank: true
        end
      end

      field = builder.to_hash["fields"].first
      validation = field["validations"].first
      expect(validation["options"]["with"]).to eq('\A[^@\s]+@[^@\s]+\z')
      expect(validation["options"]["allow_blank"]).to eq(true)
    end

    it "handles custom validation with validator_class" do
      builder = described_class.new(:project)
      builder.instance_eval do
        field :title, :string do
          validates :custom, validator_class: "MyValidator", custom_param: "value"
        end
      end

      field = builder.to_hash["fields"].first
      validation = field["validations"].first
      expect(validation["type"]).to eq("custom")
      expect(validation["validator_class"]).to eq("MyValidator")
      expect(validation["options"]).to eq({ "custom_param" => "value" })
    end

    it "handles conditional validations" do
      builder = described_class.new(:project)
      builder.instance_eval do
        field :title, :string do
          validates :presence, if: "active?"
        end
      end

      field = builder.to_hash["fields"].first
      validation = field["validations"].first
      expect(validation["options"]["if"]).to eq("active?")
    end

    it "omits validations key when field has no block" do
      builder = described_class.new(:project)
      builder.instance_eval do
        field :title, :string
      end

      field = builder.to_hash["fields"].first
      expect(field).not_to have_key("validations")
    end

    it "omits validations key when field block has no validates calls" do
      builder = described_class.new(:project)
      builder.instance_eval do
        field :title, :string do
          # empty block
        end
      end

      field = builder.to_hash["fields"].first
      expect(field).not_to have_key("validations")
    end
  end

  describe "model-level validations (Style B)" do
    it "attaches validation to the referenced field" do
      builder = described_class.new(:contact)
      builder.instance_eval do
        field :email, :string
        validates :email, :format, with: '\A[^@\s]+@[^@\s]+\z'
      end

      field = builder.to_hash["fields"].first
      expect(field["validations"].length).to eq(1)
      expect(field["validations"][0]["type"]).to eq("format")
    end

    it "merges model-level validations with field-level validations" do
      builder = described_class.new(:contact)
      builder.instance_eval do
        field :title, :string do
          validates :presence
        end
        validates :title, :length, minimum: 3
      end

      field = builder.to_hash["fields"].first
      expect(field["validations"].length).to eq(2)
      expect(field["validations"][0]["type"]).to eq("presence")
      expect(field["validations"][1]["type"]).to eq("length")
    end

    it "raises when referencing unknown field" do
      builder = described_class.new(:contact)
      builder.instance_eval do
        field :name, :string
        validates :email, :presence
      end

      expect { builder.to_hash }.to raise_error(
        LcpRuby::MetadataError, /references unknown field 'email'/
      )
    end

    it "supports validator_class in model-level validates" do
      builder = described_class.new(:contact)
      builder.instance_eval do
        field :email, :string
        validates :email, :custom, validator_class: "EmailValidator", strict: true
      end

      field = builder.to_hash["fields"].first
      validation = field["validations"].first
      expect(validation["type"]).to eq("custom")
      expect(validation["validator_class"]).to eq("EmailValidator")
      expect(validation["options"]).to eq({ "strict" => true })
    end
  end

  describe "model-level validations on FK fields" do
    it "converts validates on belongs_to FK field to model-level validation" do
      builder = described_class.new(:deal)
      builder.instance_eval do
        field :title, :string
        field :stage, :enum, values: %w[lead qualified negotiation]
        belongs_to :contact, model: :contact, required: false
        validates :contact_id, :presence, when: { field: :stage, operator: :in, value: %w[negotiation] }
      end

      hash = builder.to_hash

      # Should not raise MetadataError about unknown field
      # contact_id should become a model-level validation with field target
      expect(hash["validations"].length).to eq(1)
      validation = hash["validations"].first
      expect(validation["type"]).to eq("presence")
      expect(validation["field"]).to eq("contact_id")
      expect(validation["when"]).to eq({ field: :stage, operator: :in, value: %w[negotiation] })
    end

    it "converts validates on FK field with explicit foreign_key" do
      builder = described_class.new(:task)
      builder.instance_eval do
        field :title, :string
        belongs_to :author, model: :user, foreign_key: :author_id
        validates :author_id, :presence
      end

      hash = builder.to_hash

      expect(hash["validations"].length).to eq(1)
      expect(hash["validations"].first["field"]).to eq("author_id")
      expect(hash["validations"].first["type"]).to eq("presence")
    end

    it "still raises for truly unknown fields (not FK)" do
      builder = described_class.new(:deal)
      builder.instance_eval do
        field :title, :string
        belongs_to :contact, model: :contact
        validates :nonexistent_field, :presence
      end

      expect { builder.to_hash }.to raise_error(
        LcpRuby::MetadataError, /references unknown field 'nonexistent_field'/
      )
    end
  end

  describe "model-level validations (validates_model)" do
    it "produces model-level validation hash" do
      builder = described_class.new(:project)
      builder.instance_eval do
        validates_model :custom, validator_class: "DateRangeValidator"
      end

      hash = builder.to_hash
      expect(hash["validations"].length).to eq(1)
      expect(hash["validations"][0]["type"]).to eq("custom")
      expect(hash["validations"][0]["validator_class"]).to eq("DateRangeValidator")
    end

    it "includes extra options in validates_model" do
      builder = described_class.new(:project)
      builder.instance_eval do
        validates_model :custom, validator_class: "DateRangeValidator",
          start_field: "start_date", end_field: "end_date"
      end

      hash = builder.to_hash
      validation = hash["validations"].first
      expect(validation["validator_class"]).to eq("DateRangeValidator")
      expect(validation["options"]).to eq({
        "start_field" => "start_date",
        "end_field" => "end_date"
      })
    end
  end

  describe "associations" do
    it "produces belongs_to association hash" do
      builder = described_class.new(:task)
      builder.instance_eval do
        belongs_to :project, model: :project, required: true
      end

      assoc = builder.to_hash["associations"].first
      expect(assoc["type"]).to eq("belongs_to")
      expect(assoc["name"]).to eq("project")
      expect(assoc["target_model"]).to eq("project")
      expect(assoc["required"]).to eq(true)
    end

    it "produces has_many association hash" do
      builder = described_class.new(:project)
      builder.instance_eval do
        has_many :tasks, model: :task, dependent: :destroy
      end

      assoc = builder.to_hash["associations"].first
      expect(assoc["type"]).to eq("has_many")
      expect(assoc["name"]).to eq("tasks")
      expect(assoc["target_model"]).to eq("task")
      expect(assoc["dependent"]).to eq("destroy")
    end

    it "produces has_one association hash" do
      builder = described_class.new(:user)
      builder.instance_eval do
        has_one :profile, model: :profile, dependent: :destroy
      end

      assoc = builder.to_hash["associations"].first
      expect(assoc["type"]).to eq("has_one")
      expect(assoc["name"]).to eq("profile")
      expect(assoc["dependent"]).to eq("destroy")
    end

    it "does not include foreign_key in hash for belongs_to (inferred by AssociationDefinition)" do
      builder = described_class.new(:task)
      builder.instance_eval do
        belongs_to :project, model: :project
      end

      assoc = builder.to_hash["associations"].first
      expect(assoc).not_to have_key("foreign_key")
    end

    it "does not auto-infer foreign_key for has_many" do
      builder = described_class.new(:project)
      builder.instance_eval do
        has_many :tasks, model: :task
      end

      assoc = builder.to_hash["associations"].first
      expect(assoc).not_to have_key("foreign_key")
    end

    it "supports class_name for external models" do
      builder = described_class.new(:task)
      builder.instance_eval do
        belongs_to :author, class_name: "User", foreign_key: :author_id
      end

      assoc = builder.to_hash["associations"].first
      expect(assoc["class_name"]).to eq("User")
      expect(assoc["foreign_key"]).to eq("author_id")
      expect(assoc).not_to have_key("target_model")
    end

    it "supports required: false for belongs_to" do
      builder = described_class.new(:deal)
      builder.instance_eval do
        belongs_to :contact, model: :contact, required: false
      end

      assoc = builder.to_hash["associations"].first
      expect(assoc["required"]).to eq(false)
    end

    it "supports inverse_of" do
      builder = described_class.new(:project)
      builder.instance_eval do
        has_many :tasks, model: :task, inverse_of: :project
      end

      assoc = builder.to_hash["associations"].first
      expect(assoc["inverse_of"]).to eq("project")
    end

    it "supports counter_cache" do
      builder = described_class.new(:task)
      builder.instance_eval do
        belongs_to :project, model: :project, counter_cache: true
      end

      assoc = builder.to_hash["associations"].first
      expect(assoc["counter_cache"]).to be true
    end

    it "supports counter_cache with custom column name" do
      builder = described_class.new(:task)
      builder.instance_eval do
        belongs_to :project, model: :project, counter_cache: "tasks_count"
      end

      assoc = builder.to_hash["associations"].first
      expect(assoc["counter_cache"]).to eq("tasks_count")
    end

    it "supports touch" do
      builder = described_class.new(:task)
      builder.instance_eval do
        belongs_to :project, model: :project, touch: true
      end

      assoc = builder.to_hash["associations"].first
      expect(assoc["touch"]).to be true
    end

    it "supports polymorphic belongs_to" do
      builder = described_class.new(:comment)
      builder.instance_eval do
        belongs_to :commentable, polymorphic: true
      end

      assoc = builder.to_hash["associations"].first
      expect(assoc["polymorphic"]).to be true
      expect(assoc).not_to have_key("target_model")
    end

    it "supports has_many with as" do
      builder = described_class.new(:post)
      builder.instance_eval do
        has_many :comments, model: :comment, as: :commentable
      end

      assoc = builder.to_hash["associations"].first
      expect(assoc["as"]).to eq("commentable")
    end

    it "supports has_many through" do
      builder = described_class.new(:post)
      builder.instance_eval do
        has_many :tags, through: :taggings
      end

      assoc = builder.to_hash["associations"].first
      expect(assoc["through"]).to eq("taggings")
      expect(assoc).not_to have_key("target_model")
    end

    it "supports has_many through with source" do
      builder = described_class.new(:post)
      builder.instance_eval do
        has_many :tags, through: :taggings, source: :tag
      end

      assoc = builder.to_hash["associations"].first
      expect(assoc["through"]).to eq("taggings")
      expect(assoc["source"]).to eq("tag")
    end

    it "supports autosave" do
      builder = described_class.new(:project)
      builder.instance_eval do
        has_many :tasks, model: :task, autosave: true
      end

      assoc = builder.to_hash["associations"].first
      expect(assoc["autosave"]).to be true
    end

    it "supports validate" do
      builder = described_class.new(:project)
      builder.instance_eval do
        has_many :tasks, model: :task, validate: false
      end

      assoc = builder.to_hash["associations"].first
      expect(assoc["validate"]).to be false
    end
  end

  describe "scopes" do
    it "produces where scope hash" do
      builder = described_class.new(:project)
      builder.instance_eval do
        scope :active, where: { status: "active" }
      end

      scope = builder.to_hash["scopes"].first
      expect(scope["name"]).to eq("active")
      expect(scope["where"]).to eq({ "status" => "active" })
    end

    it "produces where_not scope hash" do
      builder = described_class.new(:project)
      builder.instance_eval do
        scope :not_archived, where_not: { status: "archived" }
      end

      scope = builder.to_hash["scopes"].first
      expect(scope["where_not"]).to eq({ "status" => "archived" })
    end

    it "produces order + limit scope hash" do
      builder = described_class.new(:project)
      builder.instance_eval do
        scope :recent, order: { created_at: :desc }, limit: 10
      end

      scope = builder.to_hash["scopes"].first
      expect(scope["order"]).to eq({ "created_at" => "desc" })
      expect(scope["limit"]).to eq(10)
    end

    it "supports combined scope options" do
      builder = described_class.new(:project)
      builder.instance_eval do
        scope :top_active, where: { status: "active" }, order: { value: :desc }, limit: 5
      end

      scope = builder.to_hash["scopes"].first
      expect(scope["where"]).to eq({ "status" => "active" })
      expect(scope["order"]).to eq({ "value" => "desc" })
      expect(scope["limit"]).to eq(5)
    end
  end

  describe "events" do
    it "produces lifecycle event hashes" do
      builder = described_class.new(:project)
      builder.instance_eval do
        after_create
        after_update
        before_destroy
        after_destroy
      end

      events = builder.to_hash["events"]
      expect(events.length).to eq(4)
      expect(events.map { |e| e["name"] }).to eq(%w[
        after_create after_update before_destroy after_destroy
      ])
    end

    it "supports custom names for lifecycle events" do
      builder = described_class.new(:project)
      builder.instance_eval do
        after_create :my_create_handler
      end

      event = builder.to_hash["events"].first
      expect(event["name"]).to eq("my_create_handler")
    end

    it "produces field_change event hash" do
      builder = described_class.new(:project)
      builder.instance_eval do
        on_field_change :on_status_change, field: :status
      end

      event = builder.to_hash["events"].first
      expect(event["name"]).to eq("on_status_change")
      expect(event["type"]).to eq("field_change")
      expect(event["field"]).to eq("status")
    end

    it "supports condition on field_change events" do
      builder = described_class.new(:project)
      builder.instance_eval do
        on_field_change :on_priority_change, field: :priority, condition: "priority_increased?"
      end

      event = builder.to_hash["events"].first
      expect(event["condition"]).to eq("priority_increased?")
    end
  end

  describe "scopes with array values" do
    it "handles where_not with array values" do
      builder = described_class.new(:deal)
      builder.instance_eval do
        scope :open, where_not: { stage: [ "closed_won", "closed_lost" ] }
      end

      scope = builder.to_hash["scopes"].first
      expect(scope["where_not"]).to eq({ "stage" => [ "closed_won", "closed_lost" ] })
    end
  end

  describe "associations with foreign_key" do
    it "includes foreign_key for has_many" do
      builder = described_class.new(:project)
      builder.instance_eval do
        has_many :tasks, model: :task, foreign_key: :project_id
      end

      assoc = builder.to_hash["associations"].first
      expect(assoc["foreign_key"]).to eq("project_id")
    end
  end

  describe "options" do
    it "includes timestamps true in options" do
      builder = described_class.new(:project)
      builder.instance_eval do
        timestamps true
      end

      expect(builder.to_hash["options"]["timestamps"]).to eq(true)
    end

    it "includes timestamps false in options" do
      builder = described_class.new(:project)
      builder.instance_eval do
        timestamps false
      end

      expect(builder.to_hash["options"]["timestamps"]).to eq(false)
    end

    it "includes label_method in options" do
      builder = described_class.new(:project)
      builder.instance_eval do
        label_method :title
      end

      expect(builder.to_hash["options"]["label_method"]).to eq("title")
    end
  end

  describe "#to_yaml" do
    it "produces YAML string with model key" do
      builder = described_class.new(:project)
      builder.instance_eval do
        label "Project"
        field :title, :string
      end

      yaml = builder.to_yaml
      parsed = YAML.safe_load(yaml)
      expect(parsed).to have_key("model")
      expect(parsed["model"]["name"]).to eq("project")
    end
  end

  describe "full model parity with YAML" do
    let(:fixtures_path) { File.expand_path("../../../fixtures/metadata", __dir__) }
    let(:yaml_hash) { YAML.safe_load_file(File.join(fixtures_path, "models/project.yml"))["model"] }

    it "produces the same ModelDefinition as the YAML fixture" do
      dsl_definition = LcpRuby.define_model(:project) do
        label "Project"
        label_plural "Projects"

        field :title, :string, label: "Title", limit: 255, null: false do
          validates :presence
          validates :length, minimum: 3, maximum: 255
        end

        field :status, :enum, label: "Status", default: "draft",
          values: { draft: "Draft", active: "Active", completed: "Completed", archived: "Archived" }

        field :description, :text, label: "Description"

        field :budget, :decimal, label: "Budget", precision: 12, scale: 2 do
          validates :numericality, greater_than_or_equal_to: 0, allow_nil: true
        end

        field :due_date, :date, label: "Due Date"
        field :start_date, :date, label: "Start Date"
        field :priority, :integer, label: "Priority", default: 0

        has_many :tasks, model: :task, dependent: :destroy, inverse_of: :project
        belongs_to :client, class_name: "Client", foreign_key: :client_id, required: false

        scope :active,       where: { status: "active" }
        scope :not_archived, where_not: { status: "archived" }
        scope :recent,       order: { created_at: :desc }, limit: 10

        after_create
        after_update
        on_field_change :on_status_change, field: :status

        timestamps true
        label_method :title
      end

      yaml_definition = LcpRuby::Metadata::ModelDefinition.from_hash(yaml_hash)

      # Model-level attributes
      expect(dsl_definition.name).to eq(yaml_definition.name)
      expect(dsl_definition.label).to eq(yaml_definition.label)
      expect(dsl_definition.label_plural).to eq(yaml_definition.label_plural)
      expect(dsl_definition.table_name).to eq(yaml_definition.table_name)
      expect(dsl_definition.timestamps?).to eq(yaml_definition.timestamps?)
      expect(dsl_definition.label_method).to eq(yaml_definition.label_method)

      # Fields
      expect(dsl_definition.fields.length).to eq(yaml_definition.fields.length)
      yaml_definition.fields.each do |yaml_field|
        dsl_field = dsl_definition.field(yaml_field.name)
        expect(dsl_field).not_to be_nil, "Missing field: #{yaml_field.name}"
        expect(dsl_field.type).to eq(yaml_field.type)
        expect(dsl_field.label).to eq(yaml_field.label)
        expect(dsl_field.default).to eq(yaml_field.default)
        expect(dsl_field.column_options).to eq(yaml_field.column_options)
        expect(dsl_field.validations.length).to eq(yaml_field.validations.length)

        dsl_field.validations.each_with_index do |dsl_val, i|
          yaml_val = yaml_field.validations[i]
          expect(dsl_val.type).to eq(yaml_val.type)
          expect(dsl_val.options).to eq(yaml_val.options)
        end
      end

      # Enum fields
      dsl_definition.enum_fields.each do |dsl_enum|
        yaml_enum = yaml_definition.field(dsl_enum.name)
        expect(dsl_enum.enum_value_names).to eq(yaml_enum.enum_value_names)
      end

      # Scopes
      expect(dsl_definition.scopes.length).to eq(yaml_definition.scopes.length)

      # Associations
      expect(dsl_definition.associations.length).to eq(yaml_definition.associations.length)
      yaml_definition.associations.each do |yaml_assoc|
        dsl_assoc = dsl_definition.associations.find { |a| a.name == yaml_assoc.name }
        expect(dsl_assoc).not_to be_nil, "Missing association: #{yaml_assoc.name}"
        expect(dsl_assoc.type).to eq(yaml_assoc.type)
        expect(dsl_assoc.foreign_key).to eq(yaml_assoc.foreign_key)
        expect(dsl_assoc.dependent).to eq(yaml_assoc.dependent)
        expect(dsl_assoc.required).to eq(yaml_assoc.required)
        expect(dsl_assoc.inverse_of).to eq(yaml_assoc.inverse_of)
      end

      # Events
      expect(dsl_definition.events.length).to eq(yaml_definition.events.length)
      dsl_definition.events.each_with_index do |dsl_event, i|
        yaml_event = yaml_definition.events[i]
        expect(dsl_event.name).to eq(yaml_event.name)
        expect(dsl_event.type).to eq(yaml_event.type)
        expect(dsl_event.field).to eq(yaml_event.field)
      end
    end
  end
end
