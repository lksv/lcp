require "spec_helper"

RSpec.describe LcpRuby::Dsl::DslLoader, ".load_presenters" do
  let(:fixtures_path) { Pathname.new(File.expand_path("../../../fixtures/metadata", __dir__)) }
  let(:dsl_presenters_dir) { fixtures_path.join("presenters_dsl") }

  describe ".load_presenters" do
    it "loads presenter definitions from .rb files" do
      definitions = described_class.load_presenters(dsl_presenters_dir)

      expect(definitions).to have_key("project")
      expect(definitions["project"]).to be_a(LcpRuby::Metadata::PresenterDefinition)
    end

    it "returns empty hash for non-existent directory" do
      definitions = described_class.load_presenters(Pathname.new("/nonexistent"))
      expect(definitions).to eq({})
    end

    it "produces a valid PresenterDefinition from DSL" do
      definitions = described_class.load_presenters(dsl_presenters_dir)
      presenter = definitions["project"]

      expect(presenter.name).to eq("project")
      expect(presenter.model).to eq("project")
      expect(presenter.label).to eq("Project Management")
      expect(presenter.slug).to eq("projects")
      expect(presenter.icon).to eq("folder")
      expect(presenter.default_view).to eq("table")
      expect(presenter.per_page).to eq(25)
      expect(presenter.table_columns.length).to eq(4)
      expect(presenter.collection_actions.length).to eq(1)
      expect(presenter.single_actions.length).to eq(4)
    end

    it "resolves inheritance correctly" do
      definitions = described_class.load_presenters(dsl_presenters_dir)
      child = definitions["project_public"]

      expect(child.name).to eq("project_public")
      expect(child.model).to eq("project")
      expect(child.label).to eq("Projects")
      expect(child.slug).to eq("public-projects")
      expect(child.read_only?).to eq(true)

      # Child's index replaces parent's
      expect(child.default_view).to eq("tiles")
      expect(child.per_page).to eq(12)
      expect(child.table_columns.length).to eq(2)

      # Child's show replaces parent's
      expect(child.show_config["layout"].length).to eq(1)
      expect(child.show_config["layout"][0]["section"]).to eq("Project")

      # Child's search replaces parent's
      expect(child.search_config["searchable_fields"]).to eq([ "title" ])

      # Navigation no longer on presenter (moved to view groups)
    end

    it "child inherits form from parent when not overridden" do
      definitions = described_class.load_presenters(dsl_presenters_dir)
      child = definitions["project_public"]

      # Form not defined in child, so inherited from parent
      expect(child.form_config["sections"].length).to eq(3)
      expect(child.form_config["sections"][0]["title"]).to eq("Basic Information")
    end

    it "raises on duplicate presenter names" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "dup_a.rb"), <<~RUBY)
          define_presenter :duplicate do
            model :project
          end
        RUBY

        File.write(File.join(dir, "dup_b.rb"), <<~RUBY)
          define_presenter :duplicate do
            model :project
          end
        RUBY

        expect {
          described_class.load_presenters(Pathname.new(dir))
        }.to raise_error(LcpRuby::MetadataError, /Duplicate presenter 'duplicate'/)
      end
    end

    it "raises on missing parent for inheritance" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "orphan.rb"), <<~RUBY)
          define_presenter :orphan, inherits: :nonexistent do
            model :project
            label "Orphan"
          end
        RUBY

        expect {
          described_class.load_presenters(Pathname.new(dir))
        }.to raise_error(LcpRuby::MetadataError, /inherits from 'nonexistent'.*not found/)
      end
    end

    it "raises on circular inheritance" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "a.rb"), <<~RUBY)
          define_presenter :alpha, inherits: :beta do
            model :project
          end
        RUBY

        File.write(File.join(dir, "b.rb"), <<~RUBY)
          define_presenter :beta, inherits: :alpha do
            model :project
          end
        RUBY

        expect {
          described_class.load_presenters(Pathname.new(dir))
        }.to raise_error(LcpRuby::MetadataError, /Circular inheritance/)
      end
    end

    it "raises MetadataError on Ruby syntax errors" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "bad.rb"), "define_presenter :bad do\n  end end\nend")

        expect {
          described_class.load_presenters(Pathname.new(dir))
        }.to raise_error(LcpRuby::MetadataError, /syntax error/)
      end
    end

    it "supports multiple presenters in a single file" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "multi.rb"), <<~RUBY)
          define_presenter :alpha do
            model :project
          end

          define_presenter :beta do
            model :project
          end
        RUBY

        definitions = described_class.load_presenters(Pathname.new(dir))
        expect(definitions.keys).to contain_exactly("alpha", "beta")
      end
    end

    it "supports description on index, show, and form views" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "desc.rb"), <<~RUBY)
          define_presenter :desc_test do
            model :project
            slug "desc-test"

            index do
              description "This is the index description."
              column :title
            end

            show do
              description "This is the show description."
              section "Details", description: "Section-level description" do
                field :title
              end
            end

            form do
              description "This is the form description."
              section "Basics", description: "Fill in basic info" do
                field :title
              end
              nested_fields "Items", association: :items, description: "Manage items"
            end
          end
        RUBY

        definitions = described_class.load_presenters(Pathname.new(dir))
        presenter = definitions["desc_test"]

        expect(presenter.index_config["description"]).to eq("This is the index description.")
        expect(presenter.show_config["description"]).to eq("This is the show description.")
        expect(presenter.show_config["layout"][0]["description"]).to eq("Section-level description")
        expect(presenter.form_config["description"]).to eq("This is the form description.")
        expect(presenter.form_config["sections"][0]["description"]).to eq("Fill in basic info")
        expect(presenter.form_config["sections"][1]["description"]).to eq("Manage items")
      end
    end

    it "supports info pseudo-field in sections" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "info.rb"), <<~RUBY)
          define_presenter :info_test do
            model :project
            slug "info-test"

            show do
              section "Details" do
                info "This explains the section."
                field :title
              end
            end

            form do
              section "Basics" do
                info "This is a helpful message."
                field :title
                divider label: "More"
                info "Another info block."
              end
            end
          end
        RUBY

        definitions = described_class.load_presenters(Pathname.new(dir))
        presenter = definitions["info_test"]

        show_fields = presenter.show_config["layout"][0]["fields"]
        expect(show_fields[0]).to eq({ "type" => "info", "text" => "This explains the section." })
        expect(show_fields[1]["field"]).to eq("title")

        form_fields = presenter.form_config["sections"][0]["fields"]
        expect(form_fields[0]).to eq({ "type" => "info", "text" => "This is a helpful message." })
        expect(form_fields[1]["field"]).to eq("title")
        expect(form_fields[2]["type"]).to eq("divider")
        expect(form_fields[3]).to eq({ "type" => "info", "text" => "Another info block." })
      end
    end

    it "resolves inheritance across separate files" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "parent.rb"), <<~RUBY)
          define_presenter :parent do
            model :project
            label "Parent"
            slug "parent"
            index do
              per_page 10
              column :title
            end
          end
        RUBY

        File.write(File.join(dir, "child.rb"), <<~RUBY)
          define_presenter :child, inherits: :parent do
            label "Child"
            slug "child"
          end
        RUBY

        definitions = described_class.load_presenters(Pathname.new(dir))
        child = definitions["child"]

        expect(child.model).to eq("project")
        expect(child.label).to eq("Child")
        expect(child.per_page).to eq(10)
        expect(child.table_columns.length).to eq(1)
      end
    end
  end
end
