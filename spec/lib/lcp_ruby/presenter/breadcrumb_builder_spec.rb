require "spec_helper"

RSpec.describe LcpRuby::Presenter::BreadcrumbBuilder do
  let(:path_helper) do
    helper = double("BreadcrumbPathHelper")
    allow(helper).to receive(:resources_path) { |slug| "/#{slug}" }
    allow(helper).to receive(:resource_path) { |slug, id| "/#{slug}/#{id}" }
    helper
  end

  def build_view_group(name:, model:, primary:, breadcrumb_config: nil)
    LcpRuby::Metadata::ViewGroupDefinition.new(
      name: name,
      model: model,
      primary_presenter: primary,
      views: [ { "presenter" => primary } ],
      breadcrumb_config: breadcrumb_config
    )
  end

  def stub_presenter(name, label:, slug:)
    presenter = instance_double(
      LcpRuby::Metadata::PresenterDefinition,
      name: name, label: label, slug: slug, model: name
    )
    allow(LcpRuby.loader).to receive(:presenter_definitions).and_return(
      LcpRuby.loader.presenter_definitions.merge(name => presenter)
    )
    presenter
  end

  before do
    allow(LcpRuby).to receive(:loader).and_return(double("Loader").as_null_object)
    allow(LcpRuby.loader).to receive(:presenter_definitions).and_return({})
    allow(LcpRuby.loader).to receive(:view_groups_for_model).and_return([])
  end

  describe "#build" do
    context "with default breadcrumbs (no breadcrumb config)" do
      it "returns Home and current view crumbs" do
        stub_presenter("items", label: "Items", slug: "items")

        vg = build_view_group(name: "items", model: "item", primary: "items")

        crumbs = described_class.new(
          view_group: vg, record: nil, action: "index", path_helper: path_helper
        ).build

        expect(crumbs.length).to eq(2)
        expect(crumbs[0].label).to eq("Home")
        expect(crumbs[0].path).to eq("/")
        expect(crumbs[1].label).to eq("Items")
        expect(crumbs[1].path).to eq("/items")
        expect(crumbs[1].current?).to be true
      end
    end

    context "with breadcrumbs disabled" do
      it "returns empty array" do
        vg = build_view_group(name: "items", model: "item", primary: "items", breadcrumb_config: false)

        crumbs = described_class.new(
          view_group: vg, record: nil, action: "index", path_helper: path_helper
        ).build

        expect(crumbs).to be_empty
      end
    end

    context "on show page with persisted record" do
      it "includes record crumb" do
        stub_presenter("items", label: "Items", slug: "items")

        vg = build_view_group(name: "items", model: "item", primary: "items")

        record = double("Record", id: 42, persisted?: true)
        allow(record).to receive(:to_label).and_return("My Item")

        crumbs = described_class.new(
          view_group: vg, record: record, action: "show", path_helper: path_helper
        ).build

        expect(crumbs.length).to eq(3)
        expect(crumbs[0].label).to eq("Home")
        expect(crumbs[1].label).to eq("Items")
        expect(crumbs[1].path).to eq("/items")
        expect(crumbs[2].label).to eq("My Item")
        expect(crumbs[2].path).to eq("/items/42")
        expect(crumbs[2].current?).to be true
      end
    end

    context "on edit page" do
      it "appends Edit crumb" do
        stub_presenter("items", label: "Items", slug: "items")

        vg = build_view_group(name: "items", model: "item", primary: "items")

        record = double("Record", id: 42, persisted?: true)
        allow(record).to receive(:to_label).and_return("My Item")

        crumbs = described_class.new(
          view_group: vg, record: record, action: "edit", path_helper: path_helper
        ).build

        expect(crumbs.length).to eq(4)
        expect(crumbs[3].label).to eq("Edit")
        expect(crumbs[3].current?).to be true
        expect(crumbs[2].current?).to be false
      end
    end

    context "on new page" do
      it "appends New crumb without record" do
        stub_presenter("items", label: "Items", slug: "items")

        vg = build_view_group(name: "items", model: "item", primary: "items")

        record = double("Record", persisted?: false)

        crumbs = described_class.new(
          view_group: vg, record: record, action: "new", path_helper: path_helper
        ).build

        expect(crumbs.length).to eq(3)
        expect(crumbs[0].label).to eq("Home")
        expect(crumbs[1].label).to eq("Items")
        expect(crumbs[2].label).to eq("New")
        expect(crumbs[2].current?).to be true
      end
    end

    context "with parent relation" do
      let(:company_model_def) do
        instance_double(LcpRuby::Metadata::ModelDefinition, associations: [])
      end

      let(:deal_model_def) do
        assoc = instance_double(
          LcpRuby::Metadata::AssociationDefinition,
          name: "company", target_model: "company", polymorphic: false
        )
        instance_double(LcpRuby::Metadata::ModelDefinition, associations: [ assoc ])
      end

      it "builds parent chain: Home > Companies > Test Corp > Deals > Big Deal" do
        stub_presenter("company", label: "Companies", slug: "companies")
        stub_presenter("deal", label: "Deals", slug: "deals")

        company_vg = build_view_group(name: "companies", model: "company", primary: "company")
        deal_vg = build_view_group(
          name: "deals", model: "deal", primary: "deal",
          breadcrumb_config: { "relation" => "company" }
        )

        parent_record = double("Company", id: 10, persisted?: true)
        allow(parent_record).to receive(:to_label).and_return("Test Corp")

        deal_record = double("Deal", id: 42, persisted?: true)
        allow(deal_record).to receive(:to_label).and_return("Big Deal")
        allow(deal_record).to receive(:company).and_return(parent_record)

        allow(LcpRuby.loader).to receive(:model_definition).with("deal").and_return(deal_model_def)
        allow(LcpRuby.loader).to receive(:model_definition).with("company").and_return(company_model_def)
        allow(LcpRuby.loader).to receive(:view_groups_for_model).with("company").and_return([ company_vg ])

        crumbs = described_class.new(
          view_group: deal_vg, record: deal_record, action: "show", path_helper: path_helper
        ).build

        expect(crumbs.map(&:label)).to eq([ "Home", "Companies", "Test Corp", "Deals", "Big Deal" ])
        expect(crumbs.map(&:path)).to eq([ "/", "/companies", "/companies/10", "/deals", "/deals/42" ])
        expect(crumbs.last.current?).to be true
      end
    end

    context "with multi-level parent chain" do
      it "builds: Home > Countries > CZ > Regions > Moravia > Cities > Brno" do
        stub_presenter("country", label: "Countries", slug: "countries")
        stub_presenter("region", label: "Regions", slug: "regions")
        stub_presenter("city", label: "Cities", slug: "cities")

        country_model_def = instance_double(LcpRuby::Metadata::ModelDefinition, associations: [])

        region_assoc = instance_double(
          LcpRuby::Metadata::AssociationDefinition,
          name: "country", target_model: "country", polymorphic: false
        )
        region_model_def = instance_double(LcpRuby::Metadata::ModelDefinition, associations: [ region_assoc ])

        city_assoc = instance_double(
          LcpRuby::Metadata::AssociationDefinition,
          name: "region", target_model: "region", polymorphic: false
        )
        city_model_def = instance_double(LcpRuby::Metadata::ModelDefinition, associations: [ city_assoc ])

        country_vg = build_view_group(name: "countries", model: "country", primary: "country")
        region_vg = build_view_group(
          name: "regions", model: "region", primary: "region",
          breadcrumb_config: { "relation" => "country" }
        )
        city_vg = build_view_group(
          name: "cities", model: "city", primary: "city",
          breadcrumb_config: { "relation" => "region" }
        )

        czech = double("Country", id: 1, persisted?: true)
        allow(czech).to receive(:to_label).and_return("CZ")

        moravia = double("Region", id: 2, persisted?: true)
        allow(moravia).to receive(:to_label).and_return("Moravia")
        allow(moravia).to receive(:country).and_return(czech)

        brno = double("City", id: 3, persisted?: true)
        allow(brno).to receive(:to_label).and_return("Brno")
        allow(brno).to receive(:region).and_return(moravia)

        allow(LcpRuby.loader).to receive(:model_definition).with("city").and_return(city_model_def)
        allow(LcpRuby.loader).to receive(:model_definition).with("region").and_return(region_model_def)
        allow(LcpRuby.loader).to receive(:model_definition).with("country").and_return(country_model_def)
        allow(LcpRuby.loader).to receive(:view_groups_for_model).with("region").and_return([ region_vg ])
        allow(LcpRuby.loader).to receive(:view_groups_for_model).with("country").and_return([ country_vg ])

        crumbs = described_class.new(
          view_group: city_vg, record: brno, action: "show", path_helper: path_helper
        ).build

        expect(crumbs.map(&:label)).to eq([ "Home", "Countries", "CZ", "Regions", "Moravia", "Cities", "Brno" ])
        expect(crumbs.map(&:path)).to eq([ "/", "/countries", "/countries/1", "/regions", "/regions/2", "/cities", "/cities/3" ])
      end
    end

    context "with polymorphic parent relation" do
      it "resolves parent model from record type column" do
        stub_presenter("comment", label: "Comments", slug: "comments")
        stub_presenter("post", label: "Posts", slug: "posts")

        poly_assoc = instance_double(
          LcpRuby::Metadata::AssociationDefinition,
          name: "commentable", target_model: nil, polymorphic: true
        )
        comment_model_def = instance_double(LcpRuby::Metadata::ModelDefinition, associations: [ poly_assoc ])
        post_model_def = instance_double(LcpRuby::Metadata::ModelDefinition, associations: [])

        comment_vg = build_view_group(
          name: "comments", model: "comment", primary: "comment",
          breadcrumb_config: { "relation" => "commentable" }
        )
        post_vg = build_view_group(name: "posts", model: "post", primary: "post")

        parent_record = double("Post", id: 5, persisted?: true)
        allow(parent_record).to receive(:to_label).and_return("My Post")

        comment_record = double("Comment", id: 1, persisted?: true)
        allow(comment_record).to receive(:to_label).and_return("Comment #1")
        allow(comment_record).to receive(:commentable).and_return(parent_record)
        allow(comment_record).to receive(:commentable_type).and_return("LcpRuby::Dynamic::Post")

        allow(LcpRuby.loader).to receive(:model_definition).with("comment").and_return(comment_model_def)
        allow(LcpRuby.loader).to receive(:model_definition).with("post").and_return(post_model_def)
        allow(LcpRuby.loader).to receive(:view_groups_for_model).with("post").and_return([ post_vg ])

        crumbs = described_class.new(
          view_group: comment_vg, record: comment_record, action: "show", path_helper: path_helper
        ).build

        expect(crumbs.map(&:label)).to eq([ "Home", "Posts", "My Post", "Comments", "Comment #1" ])
      end
    end

    context "with nullable FK (parent is nil)" do
      it "skips parent level" do
        stub_presenter("deal", label: "Deals", slug: "deals")

        assoc = instance_double(
          LcpRuby::Metadata::AssociationDefinition,
          name: "company", target_model: "company", polymorphic: false
        )
        model_def = instance_double(LcpRuby::Metadata::ModelDefinition, associations: [ assoc ])

        deal_vg = build_view_group(
          name: "deals", model: "deal", primary: "deal",
          breadcrumb_config: { "relation" => "company" }
        )

        deal_record = double("Deal", id: 42, persisted?: true)
        allow(deal_record).to receive(:to_label).and_return("Big Deal")
        allow(deal_record).to receive(:company).and_return(nil)

        allow(LcpRuby.loader).to receive(:model_definition).with("deal").and_return(model_def)

        crumbs = described_class.new(
          view_group: deal_vg, record: deal_record, action: "show", path_helper: path_helper
        ).build

        expect(crumbs.map(&:label)).to eq([ "Home", "Deals", "Big Deal" ])
      end
    end

    context "depth limit prevents infinite loops" do
      it "stops recursing at MAX_DEPTH for circular references" do
        stub_presenter("node", label: "Nodes", slug: "nodes")

        assoc = instance_double(
          LcpRuby::Metadata::AssociationDefinition,
          name: "parent", target_model: "node", polymorphic: false
        )
        model_def = instance_double(LcpRuby::Metadata::ModelDefinition, associations: [ assoc ])

        node_vg = build_view_group(
          name: "nodes", model: "node", primary: "node",
          breadcrumb_config: { "relation" => "parent" }
        )

        node_a = double("NodeA", id: 1, persisted?: true)
        node_b = double("NodeB", id: 2, persisted?: true)
        allow(node_a).to receive(:to_label).and_return("A")
        allow(node_b).to receive(:to_label).and_return("B")
        allow(node_a).to receive(:parent).and_return(node_b)
        allow(node_b).to receive(:parent).and_return(node_a)

        allow(LcpRuby.loader).to receive(:model_definition).with("node").and_return(model_def)
        allow(LcpRuby.loader).to receive(:view_groups_for_model).with("node").and_return([ node_vg ])

        crumbs = described_class.new(
          view_group: node_vg, record: node_a, action: "show", path_helper: path_helper
        ).build

        # MAX_DEPTH=5: depths 0..4 produce 5 levels, each with list+record crumb (10)
        # Plus: Home + current list + current record = 13 total
        expect(crumbs.length).to eq(13)
        expect(crumbs.last.current?).to be true
      end
    end

    context "last crumb is always marked current" do
      it "marks the last crumb as current" do
        stub_presenter("items", label: "Items", slug: "items")
        vg = build_view_group(name: "items", model: "item", primary: "items")

        crumbs = described_class.new(
          view_group: vg, record: nil, action: "index", path_helper: path_helper
        ).build

        non_current = crumbs[0..-2]
        expect(non_current).to all(have_attributes(current?: false))
        expect(crumbs.last.current?).to be true
      end
    end

    context "with no view group" do
      it "still returns Home crumb with nil list crumb" do
        crumbs = described_class.new(
          view_group: nil, record: nil, action: "index", path_helper: path_helper
        ).build

        expect(crumbs.length).to eq(2)
        expect(crumbs[0].label).to eq("Home")
        expect(crumbs[1].label).to eq("Unknown")
      end
    end

    context "record without to_label method" do
      it "falls back to to_s" do
        stub_presenter("items", label: "Items", slug: "items")
        vg = build_view_group(name: "items", model: "item", primary: "items")

        record = double("Record", id: 1, persisted?: true)
        allow(record).to receive(:respond_to?).with(:to_label).and_return(false)
        allow(record).to receive(:to_s).and_return("Record #1")

        crumbs = described_class.new(
          view_group: vg, record: record, action: "show", path_helper: path_helper
        ).build

        expect(crumbs[2].label).to eq("Record #1")
      end
    end

    context "configurable home path" do
      it "uses breadcrumb_home_path from configuration" do
        allow(LcpRuby.configuration).to receive(:breadcrumb_home_path).and_return("/dashboard")

        stub_presenter("items", label: "Items", slug: "items")
        vg = build_view_group(name: "items", model: "item", primary: "items")

        crumbs = described_class.new(
          view_group: vg, record: nil, action: "index", path_helper: path_helper
        ).build

        expect(crumbs[0].path).to eq("/dashboard")
      end
    end
  end

  describe described_class::Crumb do
    it "defaults current to false" do
      crumb = described_class.new(label: "Test")

      expect(crumb.current?).to be false
      expect(crumb.path).to be_nil
    end

    it "defaults path to nil" do
      crumb = described_class.new(label: "Test", current: true)

      expect(crumb.path).to be_nil
      expect(crumb.current?).to be true
    end
  end
end
