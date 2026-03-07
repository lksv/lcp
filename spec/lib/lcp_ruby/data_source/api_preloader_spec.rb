require "spec_helper"
require "ostruct"

RSpec.describe LcpRuby::DataSource::ApiPreloader do
  let(:model_def) do
    LcpRuby::Metadata::ModelDefinition.new(
      name: "preload_target",
      fields: [
        LcpRuby::Metadata::FieldDefinition.from_hash("name" => "name", "type" => "string")
      ],
      data_source_config: { "type" => "host", "provider" => "TestHostProvider" }
    )
  end

  let(:target_class) do
    builder = LcpRuby::ModelFactory::ApiBuilder.new(model_def)
    klass = builder.build
    LcpRuby.registry.register("preload_target", klass)
    klass
  end

  let(:assoc_def) do
    LcpRuby::Metadata::AssociationDefinition.new(
      type: "belongs_to",
      name: "preload_target",
      target_model: "preload_target",
      foreign_key: "target_id"
    )
  end

  before do
    target_class # ensure registered

    # Mock the loader
    allow(LcpRuby.loader).to receive(:model_definitions).and_return(
      "preload_target" => model_def
    )
  end

  it "batch loads and distributes records" do
    rec1 = target_class.new(id: "1", name: "A")
    rec2 = target_class.new(id: "2", name: "B")

    allow(target_class).to receive(:find_many).with([ "1", "2" ]).and_return([ rec1, rec2 ])

    source1 = OpenStruct.new(target_id: "1")
    source2 = OpenStruct.new(target_id: "2")
    source3 = OpenStruct.new(target_id: nil)

    described_class.preload([ source1, source2, source3 ], "preload_target", assoc_def)

    expect(source1.instance_variable_get(:@_api_assoc_preload_target)&.name).to eq("A")
    expect(source2.instance_variable_get(:@_api_assoc_preload_target)&.name).to eq("B")
    expect(source3.instance_variable_get(:@_api_assoc_preload_target)).to be_nil
  end

  it "handles empty records" do
    expect { described_class.preload([], "preload_target", assoc_def) }.not_to raise_error
  end
end
