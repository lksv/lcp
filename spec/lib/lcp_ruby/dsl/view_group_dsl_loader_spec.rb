require "spec_helper"

RSpec.describe LcpRuby::Dsl::DslLoader, ".load_view_groups" do
  describe ".load_view_groups" do
    it "returns empty hash for non-existent directory" do
      definitions = described_class.load_view_groups(Pathname.new("/nonexistent"))
      expect(definitions).to eq({})
    end

    it "loads view group definitions from .rb files" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "deals.rb"), <<~RUBY)
          define_view_group :deals do
            model :deal
            primary :deal
            navigation menu: :main, position: 3
            view :deal, label: "Detailed", icon: :maximize
            view :deal_short, label: "Short", icon: :list
          end
        RUBY

        definitions = described_class.load_view_groups(Pathname.new(dir))

        expect(definitions).to have_key("deals")
        expect(definitions["deals"]).to be_a(LcpRuby::Metadata::ViewGroupDefinition)
      end
    end

    it "produces a valid ViewGroupDefinition from DSL" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "contacts.rb"), <<~RUBY)
          define_view_group :contacts do
            model :contact
            primary :contact
            navigation menu: :main, position: 1
            view :contact, label: "Table", icon: :list
            view :contact_board, label: "Board", icon: :columns
          end
        RUBY

        definitions = described_class.load_view_groups(Pathname.new(dir))
        vg = definitions["contacts"]

        expect(vg.name).to eq("contacts")
        expect(vg.model).to eq("contact")
        expect(vg.primary_presenter).to eq("contact")
        expect(vg.navigation_config).to eq("menu" => "main", "position" => 1)
        expect(vg.presenter_names).to eq(%w[contact contact_board])
        expect(vg.has_switcher?).to be true
      end
    end

    it "supports multiple view groups in a single file" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "multi.rb"), <<~RUBY)
          define_view_group :alpha do
            model :project
            primary :project
            view :project, label: "Admin"
          end

          define_view_group :beta do
            model :task
            primary :task
            view :task, label: "Admin"
          end
        RUBY

        definitions = described_class.load_view_groups(Pathname.new(dir))
        expect(definitions.keys).to contain_exactly("alpha", "beta")
      end
    end

    it "raises on duplicate view group names within DSL files" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "dup_a.rb"), <<~RUBY)
          define_view_group :duplicate do
            model :project
            primary :project
            view :project
          end
        RUBY

        File.write(File.join(dir, "dup_b.rb"), <<~RUBY)
          define_view_group :duplicate do
            model :project
            primary :project
            view :project
          end
        RUBY

        expect {
          described_class.load_view_groups(Pathname.new(dir))
        }.to raise_error(LcpRuby::MetadataError, /Duplicate view group 'duplicate'/)
      end
    end

    it "raises MetadataError on Ruby syntax errors" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "bad.rb"), "define_view_group :bad do\n  end end\nend")

        expect {
          described_class.load_view_groups(Pathname.new(dir))
        }.to raise_error(LcpRuby::MetadataError, /syntax error/)
      end
    end
  end
end
