require "spec_helper"

RSpec.describe "Presenter Loader DSL integration" do
  describe "loading DSL presenters alongside YAML presenters" do
    it "loads .rb presenter files from presenters directory" do
      Dir.mktmpdir do |dir|
        presenters_dir = File.join(dir, "presenters")
        FileUtils.mkdir_p(presenters_dir)

        File.write(File.join(presenters_dir, "widget_admin.rb"), <<~RUBY)
          define_presenter :widget_admin do
            model :widget
            label "Widgets"
            slug "widgets"

            index do
              default_view :table
              per_page 20
              column :name, link_to: :show, sortable: true
            end

            action :create, type: :built_in, on: :collection, label: "New Widget", icon: "plus"
            action :show, type: :built_in, on: :single, icon: "eye"

            navigation menu: :main, position: 1
          end
        RUBY

        loader = LcpRuby::Metadata::Loader.new(dir)
        loader.send(:load_presenters)

        expect(loader.presenter_definitions).to have_key("widget_admin")
        presenter = loader.presenter_definition("widget_admin")
        expect(presenter.model).to eq("widget")
        expect(presenter.label).to eq("Widgets")
        expect(presenter.per_page).to eq(20)
      end
    end

    it "loads both YAML and DSL presenters" do
      Dir.mktmpdir do |dir|
        presenters_dir = File.join(dir, "presenters")
        FileUtils.mkdir_p(presenters_dir)

        # YAML presenter
        File.write(File.join(presenters_dir, "alpha.yml"), <<~YAML)
          presenter:
            name: alpha
            model: project
            slug: alpha
        YAML

        # DSL presenter
        File.write(File.join(presenters_dir, "beta.rb"), <<~RUBY)
          define_presenter :beta do
            model :project
            slug "beta"
          end
        RUBY

        loader = LcpRuby::Metadata::Loader.new(dir)
        loader.send(:load_presenters)

        expect(loader.presenter_definitions.keys).to contain_exactly("alpha", "beta")
      end
    end

    it "raises on duplicate presenter name between YAML and DSL" do
      Dir.mktmpdir do |dir|
        presenters_dir = File.join(dir, "presenters")
        FileUtils.mkdir_p(presenters_dir)

        # YAML presenter
        File.write(File.join(presenters_dir, "conflict.yml"), <<~YAML)
          presenter:
            name: conflict
            model: project
            slug: conflict
        YAML

        # DSL presenter with same name
        File.write(File.join(presenters_dir, "conflict.rb"), <<~RUBY)
          define_presenter :conflict do
            model :project
            slug "conflict"
          end
        RUBY

        loader = LcpRuby::Metadata::Loader.new(dir)

        expect {
          loader.send(:load_presenters)
        }.to raise_error(LcpRuby::MetadataError, /Duplicate presenter 'conflict'/)
      end
    end

    it "raises on duplicate presenter name within DSL files" do
      Dir.mktmpdir do |dir|
        presenters_dir = File.join(dir, "presenters")
        FileUtils.mkdir_p(presenters_dir)

        File.write(File.join(presenters_dir, "dup_a.rb"), <<~RUBY)
          define_presenter :duplicate do
            model :project
          end
        RUBY

        File.write(File.join(presenters_dir, "dup_b.rb"), <<~RUBY)
          define_presenter :duplicate do
            model :project
          end
        RUBY

        loader = LcpRuby::Metadata::Loader.new(dir)

        expect {
          loader.send(:load_presenters)
        }.to raise_error(LcpRuby::MetadataError, /Duplicate presenter 'duplicate'/)
      end
    end

    it "loads DSL presenter with inheritance" do
      Dir.mktmpdir do |dir|
        presenters_dir = File.join(dir, "presenters")
        FileUtils.mkdir_p(presenters_dir)

        File.write(File.join(presenters_dir, "parent.rb"), <<~RUBY)
          define_presenter :parent_admin do
            model :project
            label "Projects"
            slug "projects"

            index do
              default_view :table
              per_page 25
              column :title, link_to: :show
            end

            show do
              section "Details" do
                field :title, display: :heading
              end
            end

            navigation menu: :main, position: 1
          end
        RUBY

        File.write(File.join(presenters_dir, "child.rb"), <<~RUBY)
          define_presenter :child_readonly, inherits: :parent_admin do
            label "Projects (Read Only)"
            slug "projects-readonly"
            read_only true

            index do
              default_view :tiles
              per_page 12
              column :title
            end
          end
        RUBY

        loader = LcpRuby::Metadata::Loader.new(dir)
        loader.send(:load_presenters)

        parent = loader.presenter_definition("parent_admin")
        child = loader.presenter_definition("child_readonly")

        expect(parent.per_page).to eq(25)
        expect(child.per_page).to eq(12)
        expect(child.model).to eq("project")
        expect(child.read_only?).to eq(true)

        # Inherited show from parent
        expect(child.show_config["layout"][0]["section"]).to eq("Details")

        # Navigation inherited from parent
        expect(child.navigation_config["menu"]).to eq("main")
      end
    end
  end

  describe "LcpRuby.define_presenter" do
    it "returns a PresenterDefinition" do
      definition = LcpRuby.define_presenter(:widget_admin) do
        model :widget
        slug "widgets"
      end

      expect(definition).to be_a(LcpRuby::Metadata::PresenterDefinition)
      expect(definition.name).to eq("widget_admin")
      expect(definition.model).to eq("widget")
    end
  end
end
