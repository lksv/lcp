require "spec_helper"

RSpec.describe LcpRuby::ModelFactory::TreeApplicator do
  before do
    LcpRuby::Types::BuiltInTypes.register_all!
    LcpRuby::Services::BuiltInTransforms.register_all!
    LcpRuby::Services::BuiltInDefaults.register_all!
    LcpRuby::Services::BuiltInAccessors.register_all!
  end

  after do
    conn = ActiveRecord::Base.connection
    %i[tree_nodes tree_depts tree_ordered_items tree_custom_names tree_nullify_items].each do |table|
      conn.drop_table(table) if conn.table_exists?(table)
    end
  end

  def build_tree_model(name, &block)
    definition = LcpRuby.define_model(name, &block)
    LcpRuby::ModelFactory::SchemaManager.new(definition).ensure_table!
    model_class = LcpRuby::ModelFactory::Builder.new(definition).build
    LcpRuby.registry.register(definition.name, model_class)
    model_class
  end

  describe "ModelDefinition accessors" do
    it "returns defaults for tree: true" do
      definition = LcpRuby.define_model(:tree_node) do
        field :name, :string
        field :parent_id, :integer
        tree
        timestamps false
      end

      expect(definition.tree?).to be true
      expect(definition.tree_parent_field).to eq("parent_id")
      expect(definition.tree_children_name).to eq("children")
      expect(definition.tree_parent_name).to eq("parent")
      expect(definition.tree_dependent).to eq("destroy")
      expect(definition.tree_max_depth).to eq(10)
      expect(definition.tree_ordered?).to be false
      expect(definition.tree_position_field).to eq("position")
    end

    it "returns custom values for tree hash" do
      definition = LcpRuby.define_model(:tree_node) do
        field :name, :string
        field :parent_id, :integer
        tree parent_field: "parent_id", children_name: "sub_items",
             parent_name: "superior", dependent: "nullify",
             max_depth: 5, ordered: true, position_field: "sort_order"
        timestamps false
      end

      expect(definition.tree_children_name).to eq("sub_items")
      expect(definition.tree_parent_name).to eq("superior")
      expect(definition.tree_dependent).to eq("nullify")
      expect(definition.tree_max_depth).to eq(5)
      expect(definition.tree_ordered?).to be true
      expect(definition.tree_position_field).to eq("sort_order")
    end

    it "returns false for tree? when not enabled" do
      definition = LcpRuby.define_model(:tree_node) do
        field :name, :string
        timestamps false
      end

      expect(definition.tree?).to be false
    end
  end

  describe "associations" do
    let(:model_class) do
      build_tree_model(:tree_node) do
        field :name, :string
        field :parent_id, :integer
        tree
        timestamps false
      end
    end

    it "creates belongs_to :parent association" do
      expect(model_class.reflect_on_association(:parent)).to be_present
      expect(model_class.reflect_on_association(:parent).macro).to eq(:belongs_to)
    end

    it "creates has_many :children association" do
      expect(model_class.reflect_on_association(:children)).to be_present
      expect(model_class.reflect_on_association(:children).macro).to eq(:has_many)
    end

    it "parent association is optional" do
      record = model_class.new(name: "Root")
      expect(record).to be_valid
    end

    it "correctly links parent and children" do
      root = model_class.create!(name: "Root")
      child = model_class.create!(name: "Child", parent_id: root.id)

      expect(child.parent).to eq(root)
      expect(root.children).to include(child)
    end
  end

  describe "associations with custom names" do
    let(:model_class) do
      build_tree_model(:tree_custom_name) do
        field :name, :string
        field :parent_id, :integer
        tree children_name: "sub_items", parent_name: "superior"
        timestamps false
      end
    end

    it "creates custom-named associations" do
      expect(model_class.reflect_on_association(:superior)).to be_present
      expect(model_class.reflect_on_association(:sub_items)).to be_present
    end

    it "links records via custom names" do
      root = model_class.create!(name: "Root")
      child = model_class.create!(name: "Child", parent_id: root.id)

      expect(child.superior).to eq(root)
      expect(root.sub_items).to include(child)
    end
  end

  describe "scopes" do
    let(:model_class) do
      build_tree_model(:tree_node) do
        field :name, :string
        field :parent_id, :integer
        tree
        timestamps false
      end
    end

    it "roots scope returns only root nodes" do
      root1 = model_class.create!(name: "Root 1")
      root2 = model_class.create!(name: "Root 2")
      model_class.create!(name: "Child", parent_id: root1.id)

      expect(model_class.roots.pluck(:id)).to match_array([ root1.id, root2.id ])
    end

    it "leaves scope returns only leaf nodes" do
      root = model_class.create!(name: "Root")
      child = model_class.create!(name: "Child", parent_id: root.id)
      grandchild = model_class.create!(name: "Grandchild", parent_id: child.id)

      expect(model_class.leaves.pluck(:id)).to match_array([ grandchild.id ])
    end
  end

  describe "predicates" do
    let(:model_class) do
      build_tree_model(:tree_node) do
        field :name, :string
        field :parent_id, :integer
        tree
        timestamps false
      end
    end

    it "root? returns true for root nodes" do
      root = model_class.create!(name: "Root")
      expect(root.root?).to be true
    end

    it "root? returns false for child nodes" do
      root = model_class.create!(name: "Root")
      child = model_class.create!(name: "Child", parent_id: root.id)
      expect(child.root?).to be false
    end

    it "leaf? returns true for nodes without children" do
      root = model_class.create!(name: "Root")
      child = model_class.create!(name: "Child", parent_id: root.id)
      expect(child.leaf?).to be true
    end

    it "leaf? returns false for nodes with children" do
      root = model_class.create!(name: "Root")
      model_class.create!(name: "Child", parent_id: root.id)
      expect(root.leaf?).to be false
    end
  end

  describe "traversal methods" do
    let(:model_class) do
      build_tree_model(:tree_node) do
        field :name, :string
        field :parent_id, :integer
        tree
        timestamps false
      end
    end

    let!(:root) { model_class.create!(name: "Root") }
    let!(:child) { model_class.create!(name: "Child", parent_id: root.id) }
    let!(:grandchild) { model_class.create!(name: "Grandchild", parent_id: child.id) }

    describe "#ancestors" do
      it "returns empty relation for root" do
        expect(root.ancestors.to_a).to be_empty
      end

      it "returns nearest-first ancestors" do
        ancestor_names = grandchild.ancestors.pluck(:name)
        expect(ancestor_names).to eq([ "Child", "Root" ])
      end

      it "returns single parent for direct child" do
        expect(child.ancestors.pluck(:name)).to eq([ "Root" ])
      end
    end

    describe "#descendants" do
      it "returns all descendants" do
        expect(root.descendants.pluck(:id)).to match_array([ child.id, grandchild.id ])
      end

      it "returns empty relation for leaf" do
        expect(grandchild.descendants.to_a).to be_empty
      end
    end

    describe "#subtree" do
      it "includes self and all descendants" do
        expect(root.subtree.pluck(:id)).to match_array([ root.id, child.id, grandchild.id ])
      end
    end

    describe "#subtree_ids" do
      it "returns array of self + descendant IDs" do
        expect(root.subtree_ids).to match_array([ root.id, child.id, grandchild.id ])
      end
    end

    describe "#siblings" do
      it "returns nodes with same parent excluding self" do
        sibling = model_class.create!(name: "Sibling", parent_id: root.id)
        expect(child.siblings.pluck(:id)).to eq([ sibling.id ])
      end

      it "returns empty for only child" do
        expect(grandchild.siblings.to_a).to be_empty
      end
    end

    describe "#depth" do
      it "returns 0 for root" do
        expect(root.depth).to eq(0)
      end

      it "returns 1 for direct child" do
        expect(child.depth).to eq(1)
      end

      it "returns 2 for grandchild" do
        expect(grandchild.depth).to eq(2)
      end
    end

    describe "#path" do
      it "returns root-to-self path" do
        path_names = grandchild.path.pluck(:name)
        expect(path_names).to eq([ "Root", "Child", "Grandchild" ])
      end

      it "returns just self for root" do
        expect(root.path.pluck(:name)).to eq([ "Root" ])
      end
    end

    describe "#root" do
      it "returns self for root node" do
        expect(root.root).to eq(root)
      end

      it "returns root ancestor for nested node" do
        expect(grandchild.root.name).to eq("Root")
      end
    end
  end

  describe "cycle detection" do
    let(:model_class) do
      build_tree_model(:tree_node) do
        field :name, :string
        field :parent_id, :integer
        tree
        timestamps false
      end
    end

    it "prevents self-reference" do
      record = model_class.create!(name: "Test")
      record.parent_id = record.id
      expect(record).not_to be_valid
      expect(record.errors[:parent_id]).to include("cannot reference itself")
    end

    it "prevents direct cycle (A -> B -> A)" do
      a = model_class.create!(name: "A")
      b = model_class.create!(name: "B", parent_id: a.id)
      a.parent_id = b.id
      expect(a).not_to be_valid
      expect(a.errors[:parent_id]).to include("would create a cycle in the tree")
    end

    it "prevents indirect cycle (A -> B -> C -> A)" do
      a = model_class.create!(name: "A")
      b = model_class.create!(name: "B", parent_id: a.id)
      c = model_class.create!(name: "C", parent_id: b.id)
      a.parent_id = c.id
      expect(a).not_to be_valid
      expect(a.errors[:parent_id]).to include("would create a cycle in the tree")
    end

    it "allows valid reparenting" do
      root1 = model_class.create!(name: "Root 1")
      root2 = model_class.create!(name: "Root 2")
      child = model_class.create!(name: "Child", parent_id: root1.id)

      child.parent_id = root2.id
      expect(child).to be_valid
    end

    it "allows setting parent_id to nil" do
      root = model_class.create!(name: "Root")
      child = model_class.create!(name: "Child", parent_id: root.id)

      child.parent_id = nil
      expect(child).to be_valid
    end

    it "validates on create with parent_id" do
      root = model_class.create!(name: "Root")
      child = model_class.new(name: "Child", parent_id: root.id)
      expect(child).to be_valid
    end

    it "prevents max_depth exceeded" do
      model_class_shallow = build_tree_model(:tree_dept) do
        field :name, :string
        field :parent_id, :integer
        tree max_depth: 2
        timestamps false
      end

      a = model_class_shallow.create!(name: "A")
      b = model_class_shallow.create!(name: "B", parent_id: a.id)
      c = model_class_shallow.create!(name: "C", parent_id: b.id)
      d = model_class_shallow.new(name: "D", parent_id: c.id)
      expect(d).not_to be_valid
      expect(d.errors[:parent_id].first).to include("maximum tree depth")
    end
  end

  describe "class-level config accessors" do
    let(:model_class) do
      build_tree_model(:tree_node) do
        field :name, :string
        field :parent_id, :integer
        tree max_depth: 5
        timestamps false
      end
    end

    it "exposes lcp_tree_parent_field" do
      expect(model_class.lcp_tree_parent_field).to eq("parent_id")
    end

    it "exposes lcp_tree_max_depth" do
      expect(model_class.lcp_tree_max_depth).to eq(5)
    end

    it "exposes lcp_tree_children_name" do
      expect(model_class.lcp_tree_children_name).to eq("children")
    end

    it "exposes lcp_tree_parent_name" do
      expect(model_class.lcp_tree_parent_name).to eq("parent")
    end
  end

  describe "parent index" do
    it "creates index on parent_field" do
      build_tree_model(:tree_node) do
        field :name, :string
        field :parent_id, :integer
        tree
        timestamps false
      end

      conn = ActiveRecord::Base.connection
      expect(conn.index_exists?(:tree_nodes, :parent_id)).to be true
    end
  end

  describe "positioning bridge" do
    it "auto-configures positioning when ordered: true" do
      model_class = build_tree_model(:tree_ordered_item) do
        field :name, :string
        field :parent_id, :integer
        field :position, :integer
        tree ordered: true
        timestamps false
      end

      # Model should be positioned
      expect(model_class).to respond_to(:positioned)
    end

    it "does not override explicit positioning config" do
      definition = LcpRuby.define_model(:tree_ordered_item) do
        field :name, :string
        field :parent_id, :integer
        field :position, :integer
        positioning field: :position, scope: :parent_id
        tree ordered: true
        timestamps false
      end

      # Explicit positioning config should not be replaced
      expect(definition.positioned?).to be true
      expect(definition.positioning_field).to eq("position")
    end
  end

  describe "dependent option" do
    it "destroys children by default" do
      model_class = build_tree_model(:tree_node) do
        field :name, :string
        field :parent_id, :integer
        tree
        timestamps false
      end

      root = model_class.create!(name: "Root")
      model_class.create!(name: "Child", parent_id: root.id)

      expect { root.destroy }.to change { model_class.count }.from(2).to(0)
    end

    it "nullifies children with dependent: nullify" do
      model_class = build_tree_model(:tree_nullify_item) do
        field :name, :string
        field :parent_id, :integer
        tree dependent: "nullify"
        timestamps false
      end

      root = model_class.create!(name: "Root")
      child = model_class.create!(name: "Child", parent_id: root.id)

      root.destroy
      child.reload
      expect(child.parent_id).to be_nil
    end
  end
end
