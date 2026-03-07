require "spec_helper"
require "ostruct"

# Provider class for setup tests
class TestErpProvider
  def find(id)
    OpenStruct.new(id: id, title: "Product #{id}")
  end

  def search(params = {}, sort: nil, page: 1, per: 25)
    LcpRuby::SearchResult.new(records: [], total_count: 0, current_page: page, per_page: per)
  end
end

RSpec.describe LcpRuby::DataSource::Setup do
  let(:fixture_path) { File.expand_path("../../../fixtures/metadata/api_model", __dir__) }

  def setup_api_fixtures!
    LcpRuby::Types::BuiltInTypes.register_all!
    LcpRuby::Services::BuiltInTransforms.register_all!
    LcpRuby::Services::BuiltInDefaults.register_all!
    LcpRuby::Display::RendererRegistry.register_built_ins!
    LcpRuby::ViewSlots::Registry.register_built_ins!

    LcpRuby.configuration.metadata_path = fixture_path
    LcpRuby.configuration.auto_migrate = true

    loader = LcpRuby.loader
    loader.load_all

    loader.model_definitions.each_value do |model_def|
      next if model_def.virtual?
      if model_def.api_model?
        builder = LcpRuby::ModelFactory::ApiBuilder.new(model_def)
        model_class = builder.build
      else
        schema_manager = LcpRuby::ModelFactory::SchemaManager.new(model_def)
        schema_manager.ensure_table!
        builder = LcpRuby::ModelFactory::Builder.new(model_def)
        model_class = builder.build
      end
      LcpRuby.registry.register(model_def.name, model_class)
    end
  end

  it "sets up data source adapters for API models" do
    setup_api_fixtures!
    described_class.apply!(LcpRuby.loader)

    expect(LcpRuby::DataSource::Registry.available?).to be true

    # erp_product uses host adapter
    erp_adapter = LcpRuby::DataSource::Registry.adapter_for("erp_product")
    expect(erp_adapter).to be_a(LcpRuby::DataSource::ResilientWrapper)

    # external_building uses rest_json adapter (wrapped)
    building_adapter = LcpRuby::DataSource::Registry.adapter_for("external_building")
    expect(building_adapter).to be_a(LcpRuby::DataSource::ResilientWrapper)
  end

  it "attaches data source to model class" do
    setup_api_fixtures!
    described_class.apply!(LcpRuby.loader)

    model_class = LcpRuby.registry.model_for("erp_product")
    expect(model_class.lcp_data_source).to be_a(LcpRuby::DataSource::ResilientWrapper)
  end

  it "does not affect DB models" do
    setup_api_fixtures!
    described_class.apply!(LcpRuby.loader)

    expect(LcpRuby::DataSource::Registry.registered?("work_order")).to be false
  end
end
