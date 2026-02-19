require "spec_helper"

RSpec.describe LcpRuby::LayoutHelper, type: :helper do
  include described_class

  describe "#hidden_on_classes" do
    it "returns empty string for nil input" do
      expect(hidden_on_classes(nil)).to eq("")
    end

    it "returns empty string for empty hash" do
      expect(hidden_on_classes({})).to eq("")
    end

    it "returns empty string when hidden_on key is missing" do
      expect(hidden_on_classes({ "field" => "name" })).to eq("")
    end

    it "returns classes for array of breakpoints" do
      config = { "hidden_on" => %w[mobile tablet] }
      expect(hidden_on_classes(config)).to eq("lcp-hidden-mobile lcp-hidden-tablet")
    end

    it "returns class for single string breakpoint" do
      config = { "hidden_on" => "mobile" }
      expect(hidden_on_classes(config)).to eq("lcp-hidden-mobile")
    end

    it "handles single-element array" do
      config = { "hidden_on" => [ "desktop" ] }
      expect(hidden_on_classes(config)).to eq("lcp-hidden-desktop")
    end
  end

  describe "#menu_item_badge" do
    let(:user) { double("User", lcp_role: [ "admin" ], id: 1) }

    before do
      LcpRuby::Current.user = user
    end

    context "renderer form" do
      it "calls renderer and returns HTML" do
        renderer = instance_double(LcpRuby::Display::CountBadge)
        allow(renderer).to receive(:render).with(5, {}, view_context: anything).and_return(
          '<span class="lcp-menu-badge">5</span>'.html_safe
        )
        allow(LcpRuby::Display::RendererRegistry).to receive(:renderer_for).with("count_badge").and_return(renderer)

        provider = double("Provider")
        allow(provider).to receive(:call).with(user: user).and_return(5)
        allow(LcpRuby::Services::Registry).to receive(:lookup).with("data_providers", "open_tasks").and_return(provider)

        item = LcpRuby::Metadata::MenuItem.from_hash(
          "view_group" => "deals",
          "badge" => { "provider" => "open_tasks", "renderer" => "count_badge" }
        )

        result = menu_item_badge(item)
        expect(result).to include("lcp-menu-badge")
        expect(result).to include("5")
      end

      it "passes options to renderer" do
        renderer = instance_double(LcpRuby::Display::TextBadge)
        allow(renderer).to receive(:render).with("ALERT", { "color" => "#dc3545" }, view_context: anything).and_return(
          '<span class="lcp-menu-badge">ALERT</span>'.html_safe
        )
        allow(LcpRuby::Display::RendererRegistry).to receive(:renderer_for).with("text_badge").and_return(renderer)

        provider = double("Provider")
        allow(provider).to receive(:call).with(user: user).and_return("ALERT")
        allow(LcpRuby::Services::Registry).to receive(:lookup).with("data_providers", "alerts").and_return(provider)

        item = LcpRuby::Metadata::MenuItem.from_hash(
          "view_group" => "deals",
          "badge" => { "provider" => "alerts", "renderer" => "text_badge", "options" => { "color" => "#dc3545" } }
        )

        menu_item_badge(item)
        expect(renderer).to have_received(:render).with("ALERT", { "color" => "#dc3545" }, view_context: anything)
      end
    end

    context "template form" do
      it "interpolates {key} from hash data and wraps in badge span" do
        provider = double("Provider")
        allow(provider).to receive(:call).with(user: user).and_return({ "count" => 3 })
        allow(LcpRuby::Services::Registry).to receive(:lookup).with("data_providers", "unread").and_return(provider)

        item = LcpRuby::Metadata::MenuItem.from_hash(
          "view_group" => "deals",
          "badge" => { "provider" => "unread", "template" => "{count} new" }
        )

        result = menu_item_badge(item)
        expect(result).to include("3 new")
        expect(result).to include("lcp-menu-badge")
      end

      it "uses {value} for simple data" do
        provider = double("Provider")
        allow(provider).to receive(:call).with(user: user).and_return(7)
        allow(LcpRuby::Services::Registry).to receive(:lookup).with("data_providers", "count").and_return(provider)

        item = LcpRuby::Metadata::MenuItem.from_hash(
          "view_group" => "deals",
          "badge" => { "provider" => "count", "template" => "{value}" }
        )

        result = menu_item_badge(item)
        expect(result).to include("7")
      end
    end

    context "partial form" do
      it "renders partial with data local" do
        provider = double("Provider")
        allow(provider).to receive(:call).with(user: user).and_return({ "status" => "ok" })
        allow(LcpRuby::Services::Registry).to receive(:lookup).with("data_providers", "health").and_return(provider)

        # Stub the render method from ActionView
        allow(self).to receive(:render).with(
          partial: "badges/health",
          locals: { data: { "status" => "ok" } }
        ).and_return('<span class="badge-ok">OK</span>'.html_safe)

        item = LcpRuby::Metadata::MenuItem.from_hash(
          "view_group" => "deals",
          "badge" => { "provider" => "health", "partial" => "badges/health" }
        )

        result = menu_item_badge(item)
        expect(result).to include("badge-ok")
      end
    end

    context "edge cases" do
      it "returns nil when item has no badge" do
        item = LcpRuby::Metadata::MenuItem.from_hash("view_group" => "deals")

        expect(menu_item_badge(item)).to be_nil
      end

      it "returns nil when provider is not registered" do
        allow(LcpRuby::Services::Registry).to receive(:lookup).with("data_providers", "unknown").and_return(nil)

        item = LcpRuby::Metadata::MenuItem.from_hash(
          "view_group" => "deals",
          "badge" => { "provider" => "unknown", "renderer" => "count_badge" }
        )

        expect(menu_item_badge(item)).to be_nil
      end

      it "returns nil when provider returns nil" do
        provider = double("Provider")
        allow(provider).to receive(:call).with(user: user).and_return(nil)
        allow(LcpRuby::Services::Registry).to receive(:lookup).with("data_providers", "empty").and_return(provider)

        item = LcpRuby::Metadata::MenuItem.from_hash(
          "view_group" => "deals",
          "badge" => { "provider" => "empty", "renderer" => "count_badge" }
        )

        expect(menu_item_badge(item)).to be_nil
      end

      it "re-raises errors in test environment" do
        provider = double("Provider")
        allow(provider).to receive(:call).and_raise(StandardError, "boom")
        allow(LcpRuby::Services::Registry).to receive(:lookup).with("data_providers", "broken").and_return(provider)

        item = LcpRuby::Metadata::MenuItem.from_hash(
          "view_group" => "deals",
          "badge" => { "provider" => "broken", "renderer" => "count_badge" }
        )

        expect { menu_item_badge(item) }.to raise_error(StandardError, "boom")
      end
    end
  end

  describe "#visible_menu_items badge preservation" do
    before do
      loader = instance_double(LcpRuby::Metadata::Loader)
      allow(LcpRuby).to receive(:loader).and_return(loader)
      allow(loader).to receive(:menu_defined?).and_return(false)
      allow(loader).to receive(:view_group_definitions).and_return({
        "deals" => instance_double(
          LcpRuby::Metadata::ViewGroupDefinition,
          primary_presenter: "deal",
          presenter_names: [ "deal" ],
          navigable?: true
        )
      })
      allow(loader).to receive(:presenter_definitions).and_return({
        "deal" => instance_double(
          LcpRuby::Metadata::PresenterDefinition,
          name: "deal", model: "deal", routable?: true, slug: "deals"
        )
      })
      allow(loader).to receive(:permission_definition).and_raise(LcpRuby::MetadataError, "no perms")
    end

    it "preserves badge on reconstructed group items" do
      group_item = LcpRuby::Metadata::MenuItem.new(
        type: :group,
        label: "CRM",
        badge: { "provider" => "crm_alerts", "renderer" => "count_badge" },
        children: [
          LcpRuby::Metadata::MenuItem.new(type: :view_group, view_group_name: "deals")
        ]
      )

      result = visible_menu_items([ group_item ])
      expect(result.first.badge).to eq("provider" => "crm_alerts", "renderer" => "count_badge")
    end
  end

  describe "#navigable_presenters" do
    let(:admin_user) { double("User", lcp_role: [ "admin" ], id: 1) }
    let(:viewer_user) { double("User", lcp_role: [ "viewer" ], id: 2) }

    let(:presenter_admin) do
      instance_double(
        LcpRuby::Metadata::PresenterDefinition,
        name: "project",
        model: "project",
        routable?: true,
        label: "Projects",
        slug: "projects",
        icon: nil
      )
    end

    let(:presenter_restricted) do
      instance_double(
        LcpRuby::Metadata::PresenterDefinition,
        name: "project_public",
        model: "project",
        routable?: true,
        label: "Public Projects",
        slug: "projects-public",
        icon: nil
      )
    end

    let(:view_group) do
      instance_double(
        LcpRuby::Metadata::ViewGroupDefinition,
        primary_presenter: "project",
        presenter_names: [ "project" ],
        navigation_config: { "position" => 1 },
        navigable?: true
      )
    end

    let(:view_group_restricted) do
      instance_double(
        LcpRuby::Metadata::ViewGroupDefinition,
        primary_presenter: "project_public",
        presenter_names: [ "project_public" ],
        navigation_config: { "position" => 2 },
        navigable?: true
      )
    end

    let(:perm_def) do
      LcpRuby::Metadata::PermissionDefinition.new(
        model: "project",
        roles: {
          "admin" => { "crud" => %w[index show create update destroy], "presenters" => "all" },
          "viewer" => { "crud" => %w[index show], "presenters" => [ "project_public" ] }
        },
        default_role: "viewer"
      )
    end

    before do
      loader = instance_double(LcpRuby::Metadata::Loader)
      allow(LcpRuby).to receive(:loader).and_return(loader)
      allow(loader).to receive(:view_group_definitions).and_return(
        "project" => view_group,
        "project_public" => view_group_restricted
      )
      allow(loader).to receive(:navigable_view_groups).and_return([ view_group, view_group_restricted ])
      allow(loader).to receive(:presenter_definitions).and_return(
        "project" => presenter_admin,
        "project_public" => presenter_restricted
      )
      allow(loader).to receive(:permission_definition).with("project").and_return(perm_def)
    end

    it "shows all menu items for admin" do
      LcpRuby::Current.user = admin_user

      entries = navigable_presenters
      expect(entries.map { |e| e[:slug] }).to contain_exactly("projects", "projects-public")
    end

    it "filters restricted menu items for viewer" do
      LcpRuby::Current.user = viewer_user

      entries = navigable_presenters
      expect(entries.map { |e| e[:slug] }).to eq([ "projects-public" ])
    end

    it "shows all menu items when no user is set" do
      LcpRuby::Current.user = nil

      entries = navigable_presenters
      expect(entries.map { |e| e[:slug] }).to contain_exactly("projects", "projects-public")
    end

    it "filters based on default role for unknown role" do
      no_access_user = double("User", lcp_role: [ "unknown" ], id: 99)
      LcpRuby::Current.user = no_access_user

      entries = navigable_presenters
      expect(entries.map { |e| e[:slug] }).to eq([ "projects-public" ])
    end
  end
end
