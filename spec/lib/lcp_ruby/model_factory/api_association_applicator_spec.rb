require "spec_helper"

RSpec.describe LcpRuby::ModelFactory::ApiAssociationApplicator do
  def setup_cross_source_models!
    # 1. Build API model: external_building
    building_def = LcpRuby::Metadata::ModelDefinition.new(
      name: "external_building",
      fields: [
        LcpRuby::Metadata::FieldDefinition.from_hash("name" => "name", "type" => "string")
      ],
      data_source_config: { "type" => "host", "provider" => "TestHostProvider" },
      options: { "label_method" => "name" }
    )

    building_class = LcpRuby::ModelFactory::ApiBuilder.new(building_def).build
    LcpRuby.registry.register("external_building", building_class)

    # 2. Build DB model: work_order with belongs_to external_building
    work_order_def = LcpRuby::Metadata::ModelDefinition.new(
      name: "work_order",
      fields: [
        LcpRuby::Metadata::FieldDefinition.from_hash("name" => "title", "type" => "string"),
        LcpRuby::Metadata::FieldDefinition.from_hash("name" => "external_building_id", "type" => "string")
      ],
      associations: [
        LcpRuby::Metadata::AssociationDefinition.new(
          type: "belongs_to",
          name: "external_building",
          target_model: "external_building",
          foreign_key: "external_building_id"
        )
      ],
      options: { "label_method" => "title" }
    )

    @loader = double("loader")
    allow(@loader).to receive(:model_definitions).and_return({
      "external_building" => building_def,
      "work_order" => work_order_def
    })

    # Build work_order as a simple class with accessors (no real DB table needed)
    work_order_class = Class.new do
      attr_accessor :title, :external_building_id

      def initialize(attrs = {})
        attrs.each { |k, v| send(:"#{k}=", v) }
      end

      def [](key)
        send(key) if respond_to?(key)
      end
    end

    LcpRuby::Dynamic.send(:remove_const, :WorkOrder) if LcpRuby::Dynamic.const_defined?(:WorkOrder, false)
    LcpRuby::Dynamic.const_set(:WorkOrder, work_order_class)
    LcpRuby.registry.register("work_order", work_order_class)
  end

  describe "#apply!" do
    it "creates cross-source belongs_to accessor on DB model" do
      setup_cross_source_models!
      described_class.new(@loader).apply!

      work_order_class = LcpRuby.registry.model_for("work_order")
      expect(work_order_class.method_defined?(:external_building)).to be true
    end

    it "the accessor fetches from API data source" do
      setup_cross_source_models!
      building_class = LcpRuby.registry.model_for("external_building")

      building = building_class.new(id: "42", name: "Tower A")
      allow(building_class).to receive(:find).with("42").and_return(building)

      described_class.new(@loader).apply!

      work_order_class = LcpRuby.registry.model_for("work_order")
      work_order = work_order_class.new(external_building_id: "42")

      result = work_order.external_building
      expect(result.name).to eq("Tower A")
    end

    it "returns placeholder on API failure" do
      setup_cross_source_models!
      building_class = LcpRuby.registry.model_for("external_building")
      allow(building_class).to receive(:find).and_raise(
        LcpRuby::DataSource::ConnectionError, "timeout"
      )

      described_class.new(@loader).apply!

      work_order_class = LcpRuby.registry.model_for("work_order")
      work_order = work_order_class.new(external_building_id: "42")

      result = work_order.external_building
      expect(result).to be_a(LcpRuby::DataSource::ApiErrorPlaceholder)
      expect(result.error?).to be true
    end
  end
end
