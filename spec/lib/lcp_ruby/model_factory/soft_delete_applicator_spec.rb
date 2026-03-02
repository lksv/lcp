require "spec_helper"
require "ostruct"

RSpec.describe LcpRuby::ModelFactory::SoftDeleteApplicator do
  before do
    LcpRuby::Types::BuiltInTypes.register_all!
    LcpRuby::Services::BuiltInTransforms.register_all!
    LcpRuby::Services::BuiltInDefaults.register_all!
    LcpRuby::Services::BuiltInAccessors.register_all!
  end

  after do
    conn = ActiveRecord::Base.connection
    %i[sd_items sd_parents sd_children sd_grandchildren sd_custom_items].each do |table|
      conn.drop_table(table) if conn.table_exists?(table)
    end
  end

  def build_soft_deletable_model(name, &block)
    definition = LcpRuby.define_model(name, &block)
    LcpRuby::ModelFactory::SchemaManager.new(definition).ensure_table!
    model_class = LcpRuby::ModelFactory::Builder.new(definition).build
    LcpRuby.registry.register(definition.name, model_class)
    model_class
  end

  describe "basic discard and undiscard" do
    let(:model_class) do
      build_soft_deletable_model(:sd_item) do
        field :title, :string
        soft_delete
        timestamps false
      end
    end

    it "discard! sets discarded_at timestamp" do
      record = model_class.create!(title: "Test")
      record.discard!

      record.reload
      expect(record.discarded_at).to be_present
      expect(record.discarded?).to be true
      expect(record.kept?).to be false
    end

    it "undiscard! clears discarded_at timestamp" do
      record = model_class.create!(title: "Test")
      record.discard!
      record.undiscard!

      record.reload
      expect(record.discarded_at).to be_nil
      expect(record.discarded?).to be false
      expect(record.kept?).to be true
    end

    it "raises error on double discard" do
      record = model_class.create!(title: "Test")
      record.discard!

      expect { record.discard! }.to raise_error(LcpRuby::Error, /already discarded/)
    end

    it "raises error on undiscard of kept record" do
      record = model_class.create!(title: "Test")

      expect { record.undiscard! }.to raise_error(LcpRuby::Error, /not discarded/)
    end

    it "kept? and discarded? are correct predicates" do
      record = model_class.create!(title: "Test")
      expect(record.kept?).to be true
      expect(record.discarded?).to be false

      record.discard!
      expect(record.kept?).to be false
      expect(record.discarded?).to be true
    end
  end

  describe "tracking columns" do
    let(:model_class) do
      build_soft_deletable_model(:sd_item) do
        field :title, :string
        soft_delete
        timestamps false
      end
    end

    it "sets discarded_by_type and discarded_by_id when by: is provided" do
      parent = OpenStruct.new(id: 42, class: OpenStruct.new(name: "Project"))
      # We need an object whose class.name returns a string
      by_obj = model_class.create!(title: "Parent")
      record = model_class.create!(title: "Child")

      record.discard!(by: by_obj)
      record.reload

      expect(record["discarded_by_type"]).to eq(by_obj.class.name)
      expect(record["discarded_by_id"]).to eq(by_obj.id)
      expect(record.cascade_discarded?).to be true
    end

    it "does not set tracking columns without by:" do
      record = model_class.create!(title: "Test")
      record.discard!
      record.reload

      expect(record["discarded_by_type"]).to be_nil
      expect(record["discarded_by_id"]).to be_nil
      expect(record.cascade_discarded?).to be false
    end

    it "undiscard! clears tracking columns" do
      by_obj = model_class.create!(title: "Parent")
      record = model_class.create!(title: "Test")
      record.discard!(by: by_obj)
      record.undiscard!
      record.reload

      expect(record["discarded_by_type"]).to be_nil
      expect(record["discarded_by_id"]).to be_nil
    end
  end

  describe "scopes" do
    let(:model_class) do
      build_soft_deletable_model(:sd_item) do
        field :title, :string
        soft_delete
        timestamps false
      end
    end

    it "kept scope returns only kept records" do
      kept = model_class.create!(title: "Kept")
      discarded = model_class.create!(title: "Discarded")
      discarded.discard!

      expect(model_class.kept.pluck(:id)).to eq([ kept.id ])
    end

    it "discarded scope returns only discarded records" do
      kept = model_class.create!(title: "Kept")
      discarded = model_class.create!(title: "Discarded")
      discarded.discard!

      expect(model_class.discarded.pluck(:id)).to eq([ discarded.id ])
    end

    it "with_discarded scope returns all records" do
      kept = model_class.create!(title: "Kept")
      discarded = model_class.create!(title: "Discarded")
      discarded.discard!

      expect(model_class.with_discarded.pluck(:id)).to match_array([ kept.id, discarded.id ])
    end
  end

  describe "cascade discard" do
    let!(:parent_class) do
      build_soft_deletable_model(:sd_parent) do
        field :title, :string
        has_many :sd_children, model: :sd_child, dependent: :discard
        soft_delete
        timestamps false
      end
    end

    let!(:child_class) do
      build_soft_deletable_model(:sd_child) do
        field :title, :string
        belongs_to :sd_parent, model: :sd_parent
        has_many :sd_grandchildren, model: :sd_grandchild, dependent: :discard
        soft_delete
        timestamps false
      end
    end

    let!(:grandchild_class) do
      build_soft_deletable_model(:sd_grandchild) do
        field :title, :string
        belongs_to :sd_child, model: :sd_child
        soft_delete
        timestamps false
      end
    end

    it "discarding parent cascades to children" do
      parent = parent_class.create!(title: "Parent")
      child1 = child_class.create!(title: "Child 1", sd_parent_id: parent.id)
      child2 = child_class.create!(title: "Child 2", sd_parent_id: parent.id)

      parent.discard!

      child1.reload
      child2.reload
      expect(child1.discarded?).to be true
      expect(child2.discarded?).to be true
      expect(child1["discarded_by_type"]).to eq(parent.class.name)
      expect(child1["discarded_by_id"]).to eq(parent.id)
    end

    it "multi-level cascade discard (parent → child → grandchild)" do
      parent = parent_class.create!(title: "Parent")
      child = child_class.create!(title: "Child", sd_parent_id: parent.id)
      grandchild = grandchild_class.create!(title: "Grandchild", sd_child_id: child.id)

      parent.discard!

      child.reload
      grandchild.reload
      expect(child.discarded?).to be true
      expect(grandchild.discarded?).to be true
    end

    it "cascade undiscard only restores cascade-discarded children" do
      parent = parent_class.create!(title: "Parent")
      child_cascade = child_class.create!(title: "Cascade Child", sd_parent_id: parent.id)
      child_manual = child_class.create!(title: "Manual Child", sd_parent_id: parent.id)

      # Manually discard one child first
      child_manual.discard!

      # Now discard the parent (cascades to child_cascade only, since child_manual is already discarded)
      parent.discard!

      # Restore parent
      parent.undiscard!

      child_cascade.reload
      child_manual.reload
      expect(child_cascade.discarded?).to be false
      expect(child_manual.discarded?).to be true
    end

    it "does not cascade discard to children of other parents" do
      parent1 = parent_class.create!(title: "Parent 1")
      parent2 = parent_class.create!(title: "Parent 2")
      child1 = child_class.create!(title: "Child of P1", sd_parent_id: parent1.id)
      child2 = child_class.create!(title: "Child of P2", sd_parent_id: parent2.id)

      parent1.discard!

      child1.reload
      child2.reload
      expect(child1.discarded?).to be true
      expect(child2.discarded?).to be false
    end
  end

  describe "custom column name" do
    let(:model_class) do
      build_soft_deletable_model(:sd_custom_item) do
        field :title, :string
        soft_delete column: "deleted_at"
        timestamps false
      end
    end

    it "uses the custom column name" do
      expect(model_class.lcp_soft_delete_column).to eq("deleted_at")
    end

    it "discard! sets the custom column" do
      record = model_class.create!(title: "Test")
      record.discard!
      record.reload

      expect(record["deleted_at"]).to be_present
      expect(record.discarded?).to be true
    end

    it "scopes use the custom column" do
      kept = model_class.create!(title: "Kept")
      discarded = model_class.create!(title: "Discarded")
      discarded.discard!

      expect(model_class.kept.pluck(:id)).to eq([ kept.id ])
      expect(model_class.discarded.pluck(:id)).to eq([ discarded.id ])
    end
  end

  describe "events" do
    let(:model_class) do
      build_soft_deletable_model(:sd_item) do
        field :title, :string
        soft_delete
        timestamps false
      end
    end

    it "dispatches after_discard event" do
      record = model_class.create!(title: "Test")

      expect(LcpRuby::Events::Dispatcher).to receive(:dispatch)
        .with(event_name: "after_discard", record: record)
      record.discard!
    end

    it "dispatches after_undiscard event" do
      record = model_class.create!(title: "Test")
      record.discard!

      expect(LcpRuby::Events::Dispatcher).to receive(:dispatch)
        .with(event_name: "after_undiscard", record: record)
      record.undiscard!
    end
  end

  describe "no soft_delete" do
    let(:model_class) do
      build_soft_deletable_model(:sd_item) do
        field :title, :string
        timestamps false
      end
    end

    it "does not define soft delete methods" do
      record = model_class.create!(title: "Test")
      expect(record).not_to respond_to(:discard!)
      expect(record).not_to respond_to(:undiscard!)
      expect(record).not_to respond_to(:discarded?)
      expect(record).not_to respond_to(:kept?)
    end

    it "does not define soft delete scopes" do
      expect(model_class).not_to respond_to(:kept)
      expect(model_class).not_to respond_to(:discarded)
      expect(model_class).not_to respond_to(:with_discarded)
    end
  end
end
