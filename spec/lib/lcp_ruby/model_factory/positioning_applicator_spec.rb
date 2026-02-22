require "spec_helper"

RSpec.describe LcpRuby::ModelFactory::PositioningApplicator do
  before do
    LcpRuby::Types::BuiltInTypes.register_all!
    LcpRuby::Services::BuiltInTransforms.register_all!
    LcpRuby::Services::BuiltInDefaults.register_all!
    LcpRuby::Services::BuiltInAccessors.register_all!
  end

  after do
    conn = ActiveRecord::Base.connection
    %i[pos_tests pos_scoped_tests].each do |table|
      conn.drop_table(table) if conn.table_exists?(table)
    end
  end

  def build_positioned_model(name, &block)
    definition = LcpRuby.define_model(name, &block)
    LcpRuby::ModelFactory::SchemaManager.new(definition).ensure_table!
    LcpRuby::ModelFactory::Builder.new(definition).build
  end

  describe "unscoped positioning" do
    let(:model_class) do
      build_positioned_model(:pos_test) do
        field :title, :string
        field :position, :integer
        positioning
        timestamps false
      end
    end

    it "assigns sequential positions on create" do
      a = model_class.create!(title: "First")
      b = model_class.create!(title: "Second")
      c = model_class.create!(title: "Third")

      expect(a.reload.position).to eq(1)
      expect(b.reload.position).to eq(2)
      expect(c.reload.position).to eq(3)
    end

    it "closes gaps on destroy" do
      a = model_class.create!(title: "First")
      b = model_class.create!(title: "Second")
      c = model_class.create!(title: "Third")

      b.destroy!

      expect(a.reload.position).to eq(1)
      expect(c.reload.position).to eq(2)
    end

    it "supports repositioning via update" do
      a = model_class.create!(title: "First")
      b = model_class.create!(title: "Second")
      c = model_class.create!(title: "Third")

      # Move c to first position
      c.update!(position: 1)

      expect(c.reload.position).to eq(1)
      expect(a.reload.position).to eq(2)
      expect(b.reload.position).to eq(3)
    end
  end

  describe "scoped positioning" do
    let(:model_class) do
      build_positioned_model(:pos_scoped_test) do
        field :title, :string
        field :position, :integer
        field :group_id, :integer
        positioning field: :position, scope: :group_id
        timestamps false
      end
    end

    it "assigns independent positions per scope" do
      a1 = model_class.create!(title: "G1-A", group_id: 1)
      a2 = model_class.create!(title: "G1-B", group_id: 1)
      b1 = model_class.create!(title: "G2-A", group_id: 2)
      b2 = model_class.create!(title: "G2-B", group_id: 2)

      expect(a1.reload.position).to eq(1)
      expect(a2.reload.position).to eq(2)
      expect(b1.reload.position).to eq(1)
      expect(b2.reload.position).to eq(2)
    end

    it "closes gaps within scope on destroy" do
      a1 = model_class.create!(title: "G1-A", group_id: 1)
      a2 = model_class.create!(title: "G1-B", group_id: 1)
      a3 = model_class.create!(title: "G1-C", group_id: 1)
      b1 = model_class.create!(title: "G2-A", group_id: 2)

      a2.destroy!

      expect(a1.reload.position).to eq(1)
      expect(a3.reload.position).to eq(2)
      # Other scope unaffected
      expect(b1.reload.position).to eq(1)
    end
  end

  describe "no positioning" do
    it "does not add positioned behavior when positioning absent" do
      model_class = build_positioned_model(:pos_test) do
        field :title, :string
        timestamps false
      end

      # positioning_columns should be empty when no positioning declared
      expect(model_class.positioning_columns).to be_empty
    end
  end
end
