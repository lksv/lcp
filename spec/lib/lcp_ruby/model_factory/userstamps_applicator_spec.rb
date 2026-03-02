require "spec_helper"
require "ostruct"

RSpec.describe LcpRuby::ModelFactory::UserstampsApplicator do
  before do
    LcpRuby::Types::BuiltInTypes.register_all!
    LcpRuby::Services::BuiltInTransforms.register_all!
    LcpRuby::Services::BuiltInDefaults.register_all!
    LcpRuby::Services::BuiltInAccessors.register_all!
  end

  after do
    conn = ActiveRecord::Base.connection
    %i[us_items us_named_items us_custom_items].each do |table|
      conn.drop_table(table) if conn.table_exists?(table)
    end
    LcpRuby::Current.user = nil
  end

  def build_userstamped_model(name, &block)
    definition = LcpRuby.define_model(name, &block)
    LcpRuby::ModelFactory::SchemaManager.new(definition).ensure_table!
    LcpRuby::ModelFactory::Builder.new(definition).build
  end

  def stub_user(id:, name: "Test User")
    OpenStruct.new(id: id, name: name)
  end

  describe "default userstamps (boolean true)" do
    let(:model_class) do
      build_userstamped_model(:us_item) do
        field :title, :string
        userstamps
        timestamps false
      end
    end

    it "sets created_by_id and updated_by_id on create" do
      LcpRuby::Current.user = stub_user(id: 42)
      record = model_class.create!(title: "Test")

      expect(record.created_by_id).to eq(42)
      expect(record.updated_by_id).to eq(42)
    end

    it "only updates updated_by_id on update (creator unchanged)" do
      LcpRuby::Current.user = stub_user(id: 42)
      record = model_class.create!(title: "Test")

      LcpRuby::Current.user = stub_user(id: 99)
      record.update!(title: "Updated")

      expect(record.created_by_id).to eq(42)
      expect(record.updated_by_id).to eq(99)
    end

    it "writes nil when no user is present" do
      LcpRuby::Current.user = nil
      record = model_class.create!(title: "Seeded")

      expect(record.created_by_id).to be_nil
      expect(record.updated_by_id).to be_nil
    end

    it "defines belongs_to :created_by association" do
      reflection = model_class.reflect_on_association(:created_by)
      expect(reflection).not_to be_nil
      expect(reflection.macro).to eq(:belongs_to)
      expect(reflection.options[:optional]).to be true
      expect(reflection.foreign_key.to_s).to eq("created_by_id")
      expect(reflection.options[:class_name]).to eq("User")
    end

    it "defines belongs_to :updated_by association" do
      reflection = model_class.reflect_on_association(:updated_by)
      expect(reflection).not_to be_nil
      expect(reflection.macro).to eq(:belongs_to)
      expect(reflection.options[:optional]).to be true
      expect(reflection.foreign_key.to_s).to eq("updated_by_id")
      expect(reflection.options[:class_name]).to eq("User")
    end

    it "does not update userstamps via update_columns (bypass by design)" do
      LcpRuby::Current.user = stub_user(id: 42)
      record = model_class.create!(title: "Test")

      LcpRuby::Current.user = stub_user(id: 99)
      record.update_columns(title: "Direct SQL")

      record.reload
      expect(record.updated_by_id).to eq(42)
    end
  end

  describe "store_name: true" do
    let(:model_class) do
      build_userstamped_model(:us_named_item) do
        field :title, :string
        userstamps store_name: true
        timestamps false
      end
    end

    it "populates name columns on create" do
      LcpRuby::Current.user = stub_user(id: 10, name: "Alice")
      record = model_class.create!(title: "Test")

      expect(record.created_by_id).to eq(10)
      expect(record.updated_by_id).to eq(10)
      expect(record.created_by_name).to eq("Alice")
      expect(record.updated_by_name).to eq("Alice")
    end

    it "updates only updater name on update" do
      LcpRuby::Current.user = stub_user(id: 10, name: "Alice")
      record = model_class.create!(title: "Test")

      LcpRuby::Current.user = stub_user(id: 20, name: "Bob")
      record.update!(title: "Updated")

      expect(record.created_by_name).to eq("Alice")
      expect(record.updated_by_name).to eq("Bob")
    end

    it "writes nil names when no user is present" do
      LcpRuby::Current.user = nil
      record = model_class.create!(title: "Seeded")

      expect(record.created_by_name).to be_nil
      expect(record.updated_by_name).to be_nil
    end
  end

  describe "custom column names" do
    let(:model_class) do
      build_userstamped_model(:us_custom_item) do
        field :title, :string
        userstamps created_by: :author_id, updated_by: :editor_id, store_name: true
        timestamps false
      end
    end

    it "uses custom column names for FK fields" do
      LcpRuby::Current.user = stub_user(id: 5, name: "Charlie")
      record = model_class.create!(title: "Custom")

      expect(record.author_id).to eq(5)
      expect(record.editor_id).to eq(5)
    end

    it "derives name columns from custom FK names" do
      LcpRuby::Current.user = stub_user(id: 5, name: "Charlie")
      record = model_class.create!(title: "Custom")

      expect(record.author_name).to eq("Charlie")
      expect(record.editor_name).to eq("Charlie")
    end

    it "defines belongs_to :author and :editor associations" do
      author_ref = model_class.reflect_on_association(:author)
      expect(author_ref).not_to be_nil
      expect(author_ref.foreign_key.to_s).to eq("author_id")

      editor_ref = model_class.reflect_on_association(:editor)
      expect(editor_ref).not_to be_nil
      expect(editor_ref.foreign_key.to_s).to eq("editor_id")
    end
  end

  describe "no userstamps" do
    it "does not add callback or associations when userstamps absent" do
      model_class = build_userstamped_model(:us_item) do
        field :title, :string
        timestamps false
      end

      expect(model_class.reflect_on_association(:created_by)).to be_nil
      expect(model_class.reflect_on_association(:updated_by)).to be_nil
    end
  end
end
