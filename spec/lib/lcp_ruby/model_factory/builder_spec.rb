require "spec_helper"

RSpec.describe LcpRuby::ModelFactory::Builder do
  let(:fixtures_path) { File.expand_path("../../../fixtures/metadata", __dir__) }
  let(:model_hash) do
    YAML.safe_load_file(File.join(fixtures_path, "models/project.yml"))["model"]
  end
  let(:model_definition) { LcpRuby::Metadata::ModelDefinition.from_hash(model_hash) }

  # Task model is needed because project has `has_many :tasks, dependent: :destroy`
  let(:task_hash) do
    YAML.safe_load_file(File.join(fixtures_path, "models/task.yml"))["model"]
  end
  let(:task_definition) { LcpRuby::Metadata::ModelDefinition.from_hash(task_hash) }

  before do
    LcpRuby::ModelFactory::SchemaManager.new(task_definition).ensure_table!
    LcpRuby::ModelFactory::Builder.new(task_definition).build

    LcpRuby::ModelFactory::SchemaManager.new(model_definition).ensure_table!
  end

  after do
    ActiveRecord::Base.connection.drop_table(:projects) if ActiveRecord::Base.connection.table_exists?(:projects)
    ActiveRecord::Base.connection.drop_table(:tasks) if ActiveRecord::Base.connection.table_exists?(:tasks)
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

    describe "association options" do
      it "passes inverse_of to has_many" do
        reflection = model_class.reflect_on_association(:tasks)
        expect(reflection).not_to be_nil
        expect(reflection.options[:inverse_of]).to eq(:project)
      end
    end
  end

  context "with belongs_to options (counter_cache, touch, dependent)" do
    let(:parent_hash) do
      {
        "name" => "department",
        "fields" => [
          { "name" => "name", "type" => "string" },
          { "name" => "employees_count", "type" => "integer", "default" => 0 }
        ],
        "options" => { "timestamps" => true }
      }
    end
    let(:child_hash) do
      {
        "name" => "employee",
        "fields" => [
          { "name" => "name", "type" => "string" }
        ],
        "associations" => [
          {
            "type" => "belongs_to",
            "name" => "department",
            "target_model" => "department",
            "counter_cache" => true,
            "touch" => true,
            "dependent" => "destroy"
          }
        ],
        "options" => { "timestamps" => false }
      }
    end

    let(:parent_definition) { LcpRuby::Metadata::ModelDefinition.from_hash(parent_hash) }
    let(:child_definition) { LcpRuby::Metadata::ModelDefinition.from_hash(child_hash) }

    before do
      LcpRuby::ModelFactory::SchemaManager.new(parent_definition).ensure_table!
      LcpRuby::ModelFactory::Builder.new(parent_definition).build
      LcpRuby::ModelFactory::SchemaManager.new(child_definition).ensure_table!
    end

    after do
      ActiveRecord::Base.connection.drop_table(:departments) if ActiveRecord::Base.connection.table_exists?(:departments)
      ActiveRecord::Base.connection.drop_table(:employees) if ActiveRecord::Base.connection.table_exists?(:employees)
    end

    it "passes counter_cache to belongs_to" do
      child_class = LcpRuby::ModelFactory::Builder.new(child_definition).build
      reflection = child_class.reflect_on_association(:department)
      # AR normalizes `counter_cache: true` to a hash like {active: true, column: nil}
      expect(reflection.options[:counter_cache]).to be_truthy
    end

    it "passes touch to belongs_to" do
      child_class = LcpRuby::ModelFactory::Builder.new(child_definition).build
      reflection = child_class.reflect_on_association(:department)
      expect(reflection.options[:touch]).to be true
    end

    it "passes dependent to belongs_to" do
      child_class = LcpRuby::ModelFactory::Builder.new(child_definition).build
      reflection = child_class.reflect_on_association(:department)
      expect(reflection.options[:dependent]).to eq(:destroy)
    end
  end

  context "with autosave and validate options" do
    let(:parent_hash) do
      {
        "name" => "catalog",
        "fields" => [
          { "name" => "name", "type" => "string" }
        ],
        "associations" => [
          {
            "type" => "has_many",
            "name" => "products",
            "target_model" => "product",
            "autosave" => true,
            "validate" => false
          }
        ],
        "options" => { "timestamps" => false }
      }
    end
    let(:child_hash) do
      {
        "name" => "product",
        "fields" => [
          { "name" => "title", "type" => "string" }
        ],
        "associations" => [
          { "type" => "belongs_to", "name" => "catalog", "target_model" => "catalog" }
        ],
        "options" => { "timestamps" => false }
      }
    end

    let(:parent_definition) { LcpRuby::Metadata::ModelDefinition.from_hash(parent_hash) }
    let(:child_definition) { LcpRuby::Metadata::ModelDefinition.from_hash(child_hash) }

    before do
      LcpRuby::ModelFactory::SchemaManager.new(child_definition).ensure_table!
      LcpRuby::ModelFactory::Builder.new(child_definition).build
      LcpRuby::ModelFactory::SchemaManager.new(parent_definition).ensure_table!
    end

    after do
      ActiveRecord::Base.connection.drop_table(:catalogs) if ActiveRecord::Base.connection.table_exists?(:catalogs)
      ActiveRecord::Base.connection.drop_table(:products) if ActiveRecord::Base.connection.table_exists?(:products)
    end

    it "passes autosave to has_many" do
      parent_class = LcpRuby::ModelFactory::Builder.new(parent_definition).build
      reflection = parent_class.reflect_on_association(:products)
      expect(reflection.options[:autosave]).to be true
    end

    it "passes validate to has_many" do
      parent_class = LcpRuby::ModelFactory::Builder.new(parent_definition).build
      reflection = parent_class.reflect_on_association(:products)
      expect(reflection.options[:validate]).to be false
    end
  end

  context "with has_many as (polymorphic parent side)" do
    let(:post_hash) do
      {
        "name" => "post",
        "fields" => [
          { "name" => "title", "type" => "string" }
        ],
        "associations" => [
          {
            "type" => "has_many",
            "name" => "reactions",
            "target_model" => "reaction",
            "as" => "reactable"
          }
        ],
        "options" => { "timestamps" => false }
      }
    end
    let(:reaction_hash) do
      {
        "name" => "reaction",
        "fields" => [
          { "name" => "emoji", "type" => "string" }
        ],
        "associations" => [
          {
            "type" => "belongs_to",
            "name" => "reactable",
            "polymorphic" => true,
            "required" => false
          }
        ],
        "options" => { "timestamps" => false }
      }
    end

    let(:post_definition) { LcpRuby::Metadata::ModelDefinition.from_hash(post_hash) }
    let(:reaction_definition) { LcpRuby::Metadata::ModelDefinition.from_hash(reaction_hash) }

    before do
      LcpRuby::ModelFactory::SchemaManager.new(reaction_definition).ensure_table!
      LcpRuby::ModelFactory::Builder.new(reaction_definition).build
      LcpRuby::ModelFactory::SchemaManager.new(post_definition).ensure_table!
    end

    after do
      ActiveRecord::Base.connection.drop_table(:posts) if ActiveRecord::Base.connection.table_exists?(:posts)
      ActiveRecord::Base.connection.drop_table(:reactions) if ActiveRecord::Base.connection.table_exists?(:reactions)
    end

    it "passes as to has_many" do
      post_class = LcpRuby::ModelFactory::Builder.new(post_definition).build
      reflection = post_class.reflect_on_association(:reactions)
      expect(reflection).not_to be_nil
      expect(reflection.options[:as]).to eq(:reactable)
    end
  end

  context "with has_one as (polymorphic)" do
    let(:user_hash) do
      {
        "name" => "user",
        "fields" => [
          { "name" => "name", "type" => "string" }
        ],
        "associations" => [
          {
            "type" => "has_one",
            "name" => "avatar",
            "target_model" => "image",
            "as" => "imageable"
          }
        ],
        "options" => { "timestamps" => false }
      }
    end
    let(:image_hash) do
      {
        "name" => "image",
        "fields" => [
          { "name" => "url", "type" => "string" }
        ],
        "associations" => [
          {
            "type" => "belongs_to",
            "name" => "imageable",
            "polymorphic" => true,
            "required" => false
          }
        ],
        "options" => { "timestamps" => false }
      }
    end

    let(:user_definition) { LcpRuby::Metadata::ModelDefinition.from_hash(user_hash) }
    let(:image_definition) { LcpRuby::Metadata::ModelDefinition.from_hash(image_hash) }

    before do
      LcpRuby::ModelFactory::SchemaManager.new(image_definition).ensure_table!
      LcpRuby::ModelFactory::Builder.new(image_definition).build
      LcpRuby::ModelFactory::SchemaManager.new(user_definition).ensure_table!
    end

    after do
      ActiveRecord::Base.connection.drop_table(:users) if ActiveRecord::Base.connection.table_exists?(:users)
      ActiveRecord::Base.connection.drop_table(:images) if ActiveRecord::Base.connection.table_exists?(:images)
    end

    it "passes as to has_one" do
      user_class = LcpRuby::ModelFactory::Builder.new(user_definition).build
      reflection = user_class.reflect_on_association(:avatar)
      expect(reflection).not_to be_nil
      expect(reflection.options[:as]).to eq(:imageable)
    end
  end

  context "with has_one through" do
    let(:account_hash) do
      {
        "name" => "account",
        "fields" => [],
        "associations" => [
          { "type" => "belongs_to", "name" => "supplier", "target_model" => "supplier" }
        ],
        "options" => { "timestamps" => false }
      }
    end
    let(:supplier_hash) do
      {
        "name" => "supplier",
        "fields" => [
          { "name" => "name", "type" => "string" }
        ],
        "associations" => [
          { "type" => "has_one", "name" => "account", "target_model" => "account" },
          { "type" => "has_one", "name" => "account_history", "through" => "account", "source" => "history" }
        ],
        "options" => { "timestamps" => false }
      }
    end

    let(:account_definition) { LcpRuby::Metadata::ModelDefinition.from_hash(account_hash) }
    let(:supplier_definition) { LcpRuby::Metadata::ModelDefinition.from_hash(supplier_hash) }

    before do
      LcpRuby::ModelFactory::SchemaManager.new(supplier_definition).ensure_table!
      LcpRuby::ModelFactory::Builder.new(supplier_definition).build

      LcpRuby::ModelFactory::SchemaManager.new(account_definition).ensure_table!
      LcpRuby::ModelFactory::Builder.new(account_definition).build
    end

    after do
      ActiveRecord::Base.connection.drop_table(:suppliers) if ActiveRecord::Base.connection.table_exists?(:suppliers)
      ActiveRecord::Base.connection.drop_table(:accounts) if ActiveRecord::Base.connection.table_exists?(:accounts)
    end

    it "builds AR model with has_one through" do
      # Rebuild to pick up the account association
      supplier_class = LcpRuby::ModelFactory::Builder.new(supplier_definition).build
      reflection = supplier_class.reflect_on_association(:account_history)
      expect(reflection).not_to be_nil
      expect(reflection.options[:through]).to eq(:account)
      expect(reflection.options[:source]).to eq(:history)
    end
  end

  context "with through and source on has_many" do
    let(:tag_src_hash) do
      {
        "name" => "tag_src",
        "table_name" => "tags_src",
        "fields" => [
          { "name" => "label", "type" => "string" }
        ],
        "options" => { "timestamps" => false }
      }
    end
    let(:labeling_hash) do
      {
        "name" => "labeling",
        "fields" => [],
        "associations" => [
          { "type" => "belongs_to", "name" => "tag_src", "target_model" => "tag_src" },
          { "type" => "belongs_to", "name" => "article", "target_model" => "article" }
        ],
        "options" => { "timestamps" => false }
      }
    end
    let(:article_hash) do
      {
        "name" => "article",
        "fields" => [
          { "name" => "title", "type" => "string" }
        ],
        "associations" => [
          { "type" => "has_many", "name" => "labelings", "target_model" => "labeling" },
          { "type" => "has_many", "name" => "labels", "through" => "labelings", "source" => "tag_src" }
        ],
        "options" => { "timestamps" => false }
      }
    end

    let(:tag_src_definition) { LcpRuby::Metadata::ModelDefinition.from_hash(tag_src_hash) }
    let(:labeling_definition) { LcpRuby::Metadata::ModelDefinition.from_hash(labeling_hash) }
    let(:article_definition) { LcpRuby::Metadata::ModelDefinition.from_hash(article_hash) }

    before do
      LcpRuby::ModelFactory::SchemaManager.new(tag_src_definition).ensure_table!
      LcpRuby::ModelFactory::Builder.new(tag_src_definition).build

      LcpRuby::ModelFactory::SchemaManager.new(article_definition).ensure_table!
      LcpRuby::ModelFactory::Builder.new(article_definition).build

      LcpRuby::ModelFactory::SchemaManager.new(labeling_definition).ensure_table!
      LcpRuby::ModelFactory::Builder.new(labeling_definition).build
    end

    after do
      ActiveRecord::Base.connection.drop_table(:tags_src) if ActiveRecord::Base.connection.table_exists?(:tags_src)
      ActiveRecord::Base.connection.drop_table(:labelings) if ActiveRecord::Base.connection.table_exists?(:labelings)
      ActiveRecord::Base.connection.drop_table(:articles) if ActiveRecord::Base.connection.table_exists?(:articles)
    end

    it "passes source to has_many through" do
      article_class = LcpRuby::ModelFactory::Builder.new(article_definition).build
      reflection = article_class.reflect_on_association(:labels)
      expect(reflection).not_to be_nil
      expect(reflection.options[:through]).to eq(:labelings)
      expect(reflection.options[:source]).to eq(:tag_src)
    end
  end

  context "with polymorphic associations" do
    let(:comment_hash) do
      {
        "name" => "comment",
        "fields" => [
          { "name" => "body", "type" => "text" }
        ],
        "associations" => [
          {
            "type" => "belongs_to",
            "name" => "commentable",
            "polymorphic" => true,
            "required" => false
          }
        ],
        "options" => { "timestamps" => false }
      }
    end
    let(:comment_definition) { LcpRuby::Metadata::ModelDefinition.from_hash(comment_hash) }

    before do
      LcpRuby::ModelFactory::SchemaManager.new(comment_definition).ensure_table!
    end

    after do
      ActiveRecord::Base.connection.drop_table(:comments) if ActiveRecord::Base.connection.table_exists?(:comments)
    end

    it "creates _type column for polymorphic belongs_to" do
      columns = ActiveRecord::Base.connection.columns(:comments).map(&:name)
      expect(columns).to include("commentable_id")
      expect(columns).to include("commentable_type")
    end

    it "builds AR model with polymorphic belongs_to" do
      comment_class = LcpRuby::ModelFactory::Builder.new(comment_definition).build
      reflection = comment_class.reflect_on_association(:commentable)
      expect(reflection).not_to be_nil
      expect(reflection.options[:polymorphic]).to be true
    end
  end

  context "with through associations" do
    let(:tag_hash) do
      {
        "name" => "tag",
        "fields" => [
          { "name" => "label", "type" => "string" }
        ],
        "options" => { "timestamps" => false }
      }
    end
    let(:tagging_hash) do
      {
        "name" => "tagging",
        "fields" => [],
        "associations" => [
          { "type" => "belongs_to", "name" => "tag", "target_model" => "tag" },
          { "type" => "belongs_to", "name" => "project", "target_model" => "project" }
        ],
        "options" => { "timestamps" => false }
      }
    end
    let(:project_through_hash) do
      {
        "name" => "project_through",
        "table_name" => "projects_through",
        "fields" => [
          { "name" => "title", "type" => "string" }
        ],
        "associations" => [
          { "type" => "has_many", "name" => "taggings", "target_model" => "tagging" },
          { "type" => "has_many", "name" => "tags", "through" => "taggings" }
        ],
        "options" => { "timestamps" => false }
      }
    end

    let(:tag_definition) { LcpRuby::Metadata::ModelDefinition.from_hash(tag_hash) }
    let(:tagging_definition) { LcpRuby::Metadata::ModelDefinition.from_hash(tagging_hash) }
    let(:project_through_definition) { LcpRuby::Metadata::ModelDefinition.from_hash(project_through_hash) }

    before do
      LcpRuby::ModelFactory::SchemaManager.new(tag_definition).ensure_table!
      LcpRuby::ModelFactory::Builder.new(tag_definition).build

      LcpRuby::ModelFactory::SchemaManager.new(tagging_definition).ensure_table!
      LcpRuby::ModelFactory::Builder.new(tagging_definition).build

      LcpRuby::ModelFactory::SchemaManager.new(project_through_definition).ensure_table!
    end

    after do
      ActiveRecord::Base.connection.drop_table(:tags) if ActiveRecord::Base.connection.table_exists?(:tags)
      ActiveRecord::Base.connection.drop_table(:taggings) if ActiveRecord::Base.connection.table_exists?(:taggings)
      ActiveRecord::Base.connection.drop_table(:projects_through) if ActiveRecord::Base.connection.table_exists?(:projects_through)
    end

    it "builds AR model with has_many through" do
      pt_class = LcpRuby::ModelFactory::Builder.new(project_through_definition).build
      reflection = pt_class.reflect_on_association(:tags)
      expect(reflection).not_to be_nil
      expect(reflection.options[:through]).to eq(:taggings)
    end
  end
end
