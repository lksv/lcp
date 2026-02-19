require "spec_helper"

RSpec.describe LcpRuby::Metadata::Loader, "view groups" do
  def write_model_yml(dir, name)
    models_dir = File.join(dir, "models")
    FileUtils.mkdir_p(models_dir)
    File.write(File.join(models_dir, "#{name}.yml"), <<~YAML)
      model:
        name: #{name}
        fields:
          - name: id
            type: integer
    YAML
  end

  def write_presenter_yml(dir, name, model:, slug:, label: nil)
    presenters_dir = File.join(dir, "presenters")
    FileUtils.mkdir_p(presenters_dir)
    label_line = label ? "\n  label: \"#{label}\"" : ""
    File.write(File.join(presenters_dir, "#{name}.yml"), <<~YAML)
      presenter:
        name: #{name}
        model: #{model}
        slug: #{slug}#{label_line}
    YAML
  end

  def write_view_group_yml(dir, filename, model:, primary:, views:, navigation: nil)
    views_dir = File.join(dir, "views")
    FileUtils.mkdir_p(views_dir)

    views_yaml = views.map do |v|
      entry = "    - presenter: #{v[:presenter]}"
      entry += "\n      label: \"#{v[:label]}\"" if v[:label]
      entry
    end.join("\n")

    nav_yaml = if navigation
      nav = "  navigation:\n    menu: #{navigation[:menu]}"
      nav += "\n    position: #{navigation[:position]}" if navigation[:position]
      nav + "\n"
    else
      ""
    end

    File.write(File.join(views_dir, "#{filename}.yml"), <<~YAML)
      view_group:
        model: #{model}
        primary: #{primary}
      #{nav_yaml}  views:
      #{views_yaml}
    YAML
  end

  def write_view_group_dsl(dir, filename, model:, primary:, views:)
    views_dir = File.join(dir, "views")
    FileUtils.mkdir_p(views_dir)

    view_lines = views.map do |v|
      args = ":#{v[:presenter]}"
      args += ", label: \"#{v[:label]}\"" if v[:label]
      "    view #{args}"
    end.join("\n")

    File.write(File.join(views_dir, "#{filename}.rb"), <<~RUBY)
      define_view_group :#{filename} do
        model :#{model}
        primary :#{primary}
      #{view_lines}
      end
    RUBY
  end

  describe "#load_view_groups" do
    it "loads YAML view group files from views/ directory" do
      Dir.mktmpdir do |dir|
        write_model_yml(dir, "article")
        write_presenter_yml(dir, "article", model: "article", slug: "articles")
        write_presenter_yml(dir, "article_public", model: "article", slug: "public-articles")

        write_view_group_yml(dir, "articles",
          model: "article",
          primary: "article",
          views: [
            { presenter: "article", label: "Admin" },
            { presenter: "article_public", label: "Public" }
          ],
          navigation: { menu: "main", position: 1 })

        loader = described_class.new(dir)
        loader.send(:load_models)
        loader.send(:load_presenters)
        loader.send(:load_view_groups)

        expect(loader.view_group_definitions).to have_key("articles")

        vg = loader.view_group_definitions["articles"]
        expect(vg).to be_a(LcpRuby::Metadata::ViewGroupDefinition)
        expect(vg.model).to eq("article")
        expect(vg.primary_presenter).to eq("article")
        expect(vg.presenter_names).to contain_exactly("article", "article_public")
      end
    end

    it "loads DSL view group files from views/ directory" do
      Dir.mktmpdir do |dir|
        write_model_yml(dir, "post")
        write_presenter_yml(dir, "post", model: "post", slug: "posts")

        write_view_group_dsl(dir, "posts",
          model: "post",
          primary: "post",
          views: [ { presenter: "post", label: "Admin" } ])

        loader = described_class.new(dir)
        loader.send(:load_models)
        loader.send(:load_presenters)
        loader.send(:load_view_groups)

        expect(loader.view_group_definitions).to have_key("posts")

        vg = loader.view_group_definitions["posts"]
        expect(vg).to be_a(LcpRuby::Metadata::ViewGroupDefinition)
        expect(vg.model).to eq("post")
        expect(vg.primary_presenter).to eq("post")
        expect(vg.presenter_names).to eq([ "post" ])
      end
    end

    it "raises on duplicate view group names between YAML and DSL" do
      Dir.mktmpdir do |dir|
        write_model_yml(dir, "item")
        write_presenter_yml(dir, "item", model: "item", slug: "items")

        write_view_group_yml(dir, "items",
          model: "item",
          primary: "item",
          views: [ { presenter: "item" } ])

        write_view_group_dsl(dir, "items",
          model: "item",
          primary: "item",
          views: [ { presenter: "item" } ])

        loader = described_class.new(dir)
        loader.send(:load_models)
        loader.send(:load_presenters)

        expect {
          loader.send(:load_view_groups)
        }.to raise_error(LcpRuby::MetadataError, /Duplicate view group.*items/)
      end
    end
  end

  describe "#view_groups_for_model" do
    it "returns all view groups for a model" do
      Dir.mktmpdir do |dir|
        write_model_yml(dir, "product")
        write_presenter_yml(dir, "product", model: "product", slug: "products")

        write_view_group_yml(dir, "products",
          model: "product",
          primary: "product",
          views: [ { presenter: "product" } ])

        loader = described_class.new(dir)
        loader.send(:load_models)
        loader.send(:load_presenters)
        loader.send(:load_view_groups)

        groups = loader.view_groups_for_model("product")
        expect(groups.length).to eq(1)
        expect(groups.first.name).to eq("products")
        expect(groups.first.model).to eq("product")
      end
    end

    it "returns multiple view groups when model has several" do
      Dir.mktmpdir do |dir|
        write_model_yml(dir, "deal")
        write_presenter_yml(dir, "deal", model: "deal", slug: "deals")
        write_presenter_yml(dir, "deal_pipeline", model: "deal", slug: "pipeline")

        write_view_group_yml(dir, "deals",
          model: "deal",
          primary: "deal",
          views: [ { presenter: "deal" } ])

        write_view_group_yml(dir, "pipeline",
          model: "deal",
          primary: "deal_pipeline",
          views: [ { presenter: "deal_pipeline" } ])

        loader = described_class.new(dir)
        loader.send(:load_models)
        loader.send(:load_presenters)
        loader.send(:load_view_groups)

        groups = loader.view_groups_for_model("deal")
        expect(groups.length).to eq(2)
        expect(groups.map(&:name)).to contain_exactly("deals", "pipeline")
      end
    end

    it "returns empty array when model has no view group" do
      Dir.mktmpdir do |dir|
        write_model_yml(dir, "orphan")
        write_presenter_yml(dir, "orphan", model: "orphan", slug: "orphans")

        loader = described_class.new(dir)
        loader.send(:load_models)
        loader.send(:load_presenters)
        loader.send(:load_view_groups)

        expect(loader.view_groups_for_model("orphan")).to eq([])
      end
    end
  end

  describe "#view_group_for_presenter" do
    it "finds view group containing a given presenter" do
      Dir.mktmpdir do |dir|
        write_model_yml(dir, "order")
        write_presenter_yml(dir, "order", model: "order", slug: "orders")
        write_presenter_yml(dir, "order_report", model: "order", slug: "order-reports")

        write_view_group_yml(dir, "orders",
          model: "order",
          primary: "order",
          views: [
            { presenter: "order", label: "Admin" },
            { presenter: "order_report", label: "Report" }
          ])

        loader = described_class.new(dir)
        loader.send(:load_models)
        loader.send(:load_presenters)
        loader.send(:load_view_groups)

        vg = loader.view_group_for_presenter("order_report")
        expect(vg).not_to be_nil
        expect(vg.name).to eq("orders")
        expect(vg.presenter_names).to include("order_report")
      end
    end

    it "returns nil for unknown presenter" do
      Dir.mktmpdir do |dir|
        write_model_yml(dir, "widget")
        write_presenter_yml(dir, "widget", model: "widget", slug: "widgets")

        write_view_group_yml(dir, "widgets",
          model: "widget",
          primary: "widget",
          views: [ { presenter: "widget" } ])

        loader = described_class.new(dir)
        loader.send(:load_models)
        loader.send(:load_presenters)
        loader.send(:load_view_groups)

        expect(loader.view_group_for_presenter("nonexistent")).to be_nil
      end
    end
  end

  describe "#auto_create_view_groups" do
    it "auto-creates for single-presenter models without explicit view group" do
      Dir.mktmpdir do |dir|
        write_model_yml(dir, "note")
        write_presenter_yml(dir, "note", model: "note", slug: "notes", label: "Notes")

        loader = described_class.new(dir)
        loader.load_all

        groups = loader.view_groups_for_model("note")
        expect(groups.length).to eq(1)
        vg = groups.first
        expect(vg.name).to eq("note_auto")
        expect(vg.model).to eq("note")
        expect(vg.primary_presenter).to eq("note")
        expect(vg.presenter_names).to eq([ "note" ])
      end
    end

    it "does NOT auto-create when explicit view group exists" do
      Dir.mktmpdir do |dir|
        write_model_yml(dir, "ticket")
        write_presenter_yml(dir, "ticket", model: "ticket", slug: "tickets")

        write_view_group_yml(dir, "tickets",
          model: "ticket",
          primary: "ticket",
          views: [ { presenter: "ticket" } ])

        loader = described_class.new(dir)
        loader.load_all

        # Only the explicit view group should exist, not an auto-created one
        groups = loader.view_groups_for_model("ticket")
        expect(groups.length).to eq(1)
        expect(groups.first.name).to eq("tickets")
        expect(loader.view_group_definitions).not_to have_key("ticket_auto")
      end
    end

    it "does NOT auto-create when multiple presenters exist without explicit group" do
      Dir.mktmpdir do |dir|
        write_model_yml(dir, "report")
        write_presenter_yml(dir, "report", model: "report", slug: "reports")
        write_presenter_yml(dir, "report_summary", model: "report", slug: "report-summary")

        loader = described_class.new(dir)
        loader.load_all

        expect(loader.view_groups_for_model("report")).to eq([])
        expect(loader.view_group_definitions).not_to have_key("report_auto")
      end
    end
  end

  describe "#validate_references" do
    it "raises when view group references unknown model" do
      Dir.mktmpdir do |dir|
        # Create a presenter that references a valid model, but the view group references a different one
        write_model_yml(dir, "real_model")
        write_presenter_yml(dir, "ghost_presenter", model: "real_model", slug: "ghosts")

        write_view_group_yml(dir, "ghost_group",
          model: "nonexistent_model",
          primary: "ghost_presenter",
          views: [ { presenter: "ghost_presenter" } ])

        loader = described_class.new(dir)

        expect {
          loader.load_all
        }.to raise_error(LcpRuby::MetadataError, /unknown model.*nonexistent_model/)
      end
    end

    it "raises when view group references unknown presenter" do
      Dir.mktmpdir do |dir|
        write_model_yml(dir, "valid_model")
        write_presenter_yml(dir, "valid_presenter", model: "valid_model", slug: "valids")

        write_view_group_yml(dir, "bad_refs",
          model: "valid_model",
          primary: "valid_presenter",
          views: [
            { presenter: "valid_presenter" },
            { presenter: "missing_presenter" }
          ])

        loader = described_class.new(dir)

        expect {
          loader.load_all
        }.to raise_error(LcpRuby::MetadataError, /unknown presenter.*missing_presenter/)
      end
    end

    it "raises when presenter appears in multiple view groups" do
      Dir.mktmpdir do |dir|
        write_model_yml(dir, "shared_model")
        write_presenter_yml(dir, "shared_presenter", model: "shared_model", slug: "shared")
        write_presenter_yml(dir, "other_presenter", model: "shared_model", slug: "other")

        write_view_group_yml(dir, "group_a",
          model: "shared_model",
          primary: "shared_presenter",
          views: [ { presenter: "shared_presenter" } ])

        write_view_group_yml(dir, "group_b",
          model: "shared_model",
          primary: "other_presenter",
          views: [
            { presenter: "other_presenter" },
            { presenter: "shared_presenter" }
          ])

        loader = described_class.new(dir)

        expect {
          loader.load_all
        }.to raise_error(LcpRuby::MetadataError, /multiple view groups.*group_a.*group_b/)
      end
    end
  end
end
