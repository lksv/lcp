require "spec_helper"

RSpec.describe LcpRuby::Metadata::MenuItem do
  describe ".from_hash" do
    context "separator" do
      it "creates a separator item" do
        item = described_class.from_hash("separator" => true)

        expect(item.type).to eq(:separator)
        expect(item.separator?).to be true
      end

      it "prioritizes separator over other keys" do
        item = described_class.from_hash("separator" => true, "view_group" => "deals")

        expect(item.type).to eq(:separator)
      end
    end

    context "view_group" do
      it "creates a view_group item" do
        item = described_class.from_hash("view_group" => "deals")

        expect(item.type).to eq(:view_group)
        expect(item.view_group?).to be true
        expect(item.view_group_name).to eq("deals")
      end

      it "accepts optional label, icon, and visible_when" do
        item = described_class.from_hash(
          "view_group" => "deals",
          "label" => "My Deals",
          "icon" => "dollar",
          "visible_when" => { "role" => [ "admin" ] }
        )

        expect(item.label).to eq("My Deals")
        expect(item.icon).to eq("dollar")
        expect(item.has_role_constraint?).to be true
        expect(item.allowed_roles).to eq([ "admin" ])
      end

      it "accepts position" do
        item = described_class.from_hash("view_group" => "deals", "position" => "bottom")

        expect(item.bottom?).to be true
      end
    end

    context "group (children)" do
      it "creates a group item with children" do
        item = described_class.from_hash(
          "label" => "CRM",
          "icon" => "briefcase",
          "children" => [
            { "view_group" => "deals" },
            { "separator" => true },
            { "view_group" => "companies" }
          ]
        )

        expect(item.type).to eq(:group)
        expect(item.group?).to be true
        expect(item.label).to eq("CRM")
        expect(item.children.length).to eq(3)
        expect(item.children[0].view_group?).to be true
        expect(item.children[1].separator?).to be true
        expect(item.children[2].view_group?).to be true
      end

      it "raises when label is missing" do
        expect {
          described_class.from_hash("children" => [ { "view_group" => "deals" } ])
        }.to raise_error(LcpRuby::MetadataError, /group requires a label/i)
      end
    end

    context "link" do
      it "creates a link item" do
        item = described_class.from_hash(
          "label" => "Dashboard",
          "icon" => "home",
          "url" => "/dashboard"
        )

        expect(item.type).to eq(:link)
        expect(item.link?).to be true
        expect(item.label).to eq("Dashboard")
        expect(item.url).to eq("/dashboard")
      end

      it "raises when label is missing" do
        expect {
          described_class.from_hash("url" => "/dashboard")
        }.to raise_error(LcpRuby::MetadataError, /link requires a label/i)
      end

      it "raises when url is missing for a link item" do
        # This falls through to "no valid key" error since without url and children,
        # and without view_group/separator, it's not a valid item
        expect {
          described_class.from_hash("label" => "Test")
        }.to raise_error(LcpRuby::MetadataError, /must have one of/)
      end
    end

    context "invalid" do
      it "raises when no valid key is present" do
        expect {
          described_class.from_hash("invalid" => true)
        }.to raise_error(LcpRuby::MetadataError, /must have one of/)
      end
    end
  end

  describe "#has_role_constraint?" do
    it "returns true when visible_when has role" do
      item = described_class.from_hash(
        "view_group" => "deals",
        "visible_when" => { "role" => [ "admin" ] }
      )

      expect(item.has_role_constraint?).to be true
    end

    it "returns false when visible_when is empty" do
      item = described_class.from_hash("view_group" => "deals")

      expect(item.has_role_constraint?).to be false
    end

    it "returns false when visible_when has no role key" do
      item = described_class.from_hash(
        "view_group" => "deals",
        "visible_when" => { "something" => "else" }
      )

      expect(item.has_role_constraint?).to be false
    end
  end

  describe "#allowed_roles" do
    it "returns the role array" do
      item = described_class.from_hash(
        "view_group" => "deals",
        "visible_when" => { "role" => [ "admin", "manager" ] }
      )

      expect(item.allowed_roles).to eq([ "admin", "manager" ])
    end

    it "wraps a single role string in an array" do
      item = described_class.from_hash(
        "view_group" => "deals",
        "visible_when" => { "role" => "admin" }
      )

      expect(item.allowed_roles).to eq([ "admin" ])
    end

    it "returns empty array when no constraint" do
      item = described_class.from_hash("view_group" => "deals")

      expect(item.allowed_roles).to eq([])
    end
  end

  describe "#visible_to_roles?" do
    it "returns true when no role constraint" do
      item = described_class.from_hash("view_group" => "deals")

      expect(item.visible_to_roles?([ "viewer" ])).to be true
    end

    it "returns true when user has a matching role" do
      item = described_class.from_hash(
        "view_group" => "deals",
        "visible_when" => { "role" => [ "admin", "manager" ] }
      )

      expect(item.visible_to_roles?([ "manager" ])).to be true
    end

    it "returns false when user has no matching role" do
      item = described_class.from_hash(
        "view_group" => "deals",
        "visible_when" => { "role" => [ "admin" ] }
      )

      expect(item.visible_to_roles?([ "viewer" ])).to be false
    end

    it "handles visible_when passed with symbol keys via constructor" do
      item = described_class.new(
        type: :view_group,
        view_group_name: "deals",
        visible_when: { role: [ "admin" ] }
      )

      expect(item.visible_to_roles?([ "admin" ])).to be true
      expect(item.visible_to_roles?([ "viewer" ])).to be false
    end
  end

  describe "#bottom?" do
    it "returns true when position is bottom" do
      item = described_class.from_hash("view_group" => "deals", "position" => "bottom")

      expect(item.bottom?).to be true
    end

    it "returns false when position is not set" do
      item = described_class.from_hash("view_group" => "deals")

      expect(item.bottom?).to be false
    end
  end

  describe "#contains_slug?" do
    let(:loader) do
      loader = instance_double(LcpRuby::Metadata::Loader)
      allow(loader).to receive(:view_group_definitions).and_return(view_group_defs)
      allow(loader).to receive(:presenter_definitions).and_return(presenter_defs)
      loader
    end

    let(:view_group_defs) do
      vg = LcpRuby::Metadata::ViewGroupDefinition.new(
        name: "deals",
        model: "deal",
        primary_presenter: "deal",
        views: [ { "presenter" => "deal" } ]
      )
      { "deals" => vg }
    end

    let(:presenter_defs) do
      presenter = LcpRuby::Metadata::PresenterDefinition.new(
        name: "deal",
        model: "deal",
        slug: "deals"
      )
      { "deal" => presenter }
    end

    it "returns true for a matching view group item" do
      item = described_class.from_hash("view_group" => "deals")

      expect(item.contains_slug?("deals", loader)).to be true
    end

    it "returns false for a non-matching slug" do
      item = described_class.from_hash("view_group" => "deals")

      expect(item.contains_slug?("companies", loader)).to be false
    end

    it "recurses into group children" do
      item = described_class.from_hash(
        "label" => "CRM",
        "children" => [ { "view_group" => "deals" } ]
      )

      expect(item.contains_slug?("deals", loader)).to be true
    end

    it "returns false for unknown view group" do
      item = described_class.from_hash("view_group" => "nonexistent")

      expect(item.contains_slug?("deals", loader)).to be false
    end
  end

  describe "#resolved_label / #resolved_icon / #resolved_slug" do
    let(:loader) do
      loader = instance_double(LcpRuby::Metadata::Loader)
      allow(loader).to receive(:view_group_definitions).and_return(view_group_defs)
      allow(loader).to receive(:presenter_definitions).and_return(presenter_defs)
      loader
    end

    let(:view_group_defs) do
      vg = LcpRuby::Metadata::ViewGroupDefinition.new(
        name: "deals",
        model: "deal",
        primary_presenter: "deal",
        views: [ { "presenter" => "deal" } ]
      )
      { "deals" => vg }
    end

    let(:presenter_defs) do
      presenter = LcpRuby::Metadata::PresenterDefinition.new(
        name: "deal",
        model: "deal",
        label: "Deals",
        slug: "deals",
        icon: "dollar-sign"
      )
      { "deal" => presenter }
    end

    context "when label/icon not set explicitly" do
      let(:item) { described_class.from_hash("view_group" => "deals") }

      it "resolves label from presenter" do
        expect(item.resolved_label(loader)).to eq("Deals")
      end

      it "resolves icon from presenter" do
        expect(item.resolved_icon(loader)).to eq("dollar-sign")
      end

      it "resolves slug from presenter" do
        expect(item.resolved_slug(loader)).to eq("deals")
      end
    end

    context "when label/icon set explicitly" do
      let(:item) do
        described_class.from_hash(
          "view_group" => "deals",
          "label" => "My Deals",
          "icon" => "custom-icon"
        )
      end

      it "uses explicit label" do
        expect(item.resolved_label(loader)).to eq("My Deals")
      end

      it "uses explicit icon" do
        expect(item.resolved_icon(loader)).to eq("custom-icon")
      end
    end

    context "for non-view_group items" do
      it "returns label directly for link items" do
        item = described_class.from_hash("label" => "Home", "url" => "/home")

        expect(item.resolved_label(loader)).to eq("Home")
      end

      it "returns nil for slug on link items" do
        item = described_class.from_hash("label" => "Home", "url" => "/home")

        expect(item.resolved_slug(loader)).to be_nil
      end
    end
  end

  describe "badge" do
    context "parsing" do
      it "parses badge with renderer form" do
        item = described_class.from_hash(
          "view_group" => "deals",
          "badge" => { "provider" => "open_tasks", "renderer" => "count_badge" }
        )

        expect(item.has_badge?).to be true
        expect(item.badge_provider).to eq("open_tasks")
        expect(item.badge_form).to eq(:renderer)
        expect(item.badge_renderer).to eq("count_badge")
      end

      it "parses badge with template form" do
        item = described_class.from_hash(
          "view_group" => "deals",
          "badge" => { "provider" => "unread", "template" => "{count} new" }
        )

        expect(item.badge_form).to eq(:template)
        expect(item.badge_template).to eq("{count} new")
      end

      it "parses badge with partial form" do
        item = described_class.from_hash(
          "view_group" => "deals",
          "badge" => { "provider" => "health", "partial" => "badges/health" }
        )

        expect(item.badge_form).to eq(:partial)
        expect(item.badge_partial).to eq("badges/health")
      end

      it "parses badge options" do
        item = described_class.from_hash(
          "view_group" => "deals",
          "badge" => { "provider" => "alerts", "renderer" => "text_badge", "options" => { "color" => "#dc3545" } }
        )

        expect(item.badge_options).to eq("color" => "#dc3545")
      end

      it "returns empty hash when options not set" do
        item = described_class.from_hash(
          "view_group" => "deals",
          "badge" => { "provider" => "open_tasks", "renderer" => "count_badge" }
        )

        expect(item.badge_options).to eq({})
      end

      it "parses badge on group items" do
        item = described_class.from_hash(
          "label" => "CRM",
          "badge" => { "provider" => "crm_alerts", "renderer" => "count_badge" },
          "children" => [ { "view_group" => "deals" } ]
        )

        expect(item.has_badge?).to be true
      end

      it "parses badge on link items" do
        item = described_class.from_hash(
          "label" => "Dashboard",
          "url" => "/dashboard",
          "badge" => { "provider" => "notifications", "template" => "{value}" }
        )

        expect(item.has_badge?).to be true
      end
    end

    context "has_badge?" do
      it "returns false when no badge" do
        item = described_class.from_hash("view_group" => "deals")

        expect(item.has_badge?).to be false
      end

      it "returns false for separator" do
        item = described_class.from_hash("separator" => true)

        expect(item.has_badge?).to be false
        expect(item.badge).to be_nil
      end
    end

    context "validation" do
      it "raises when badge has no provider" do
        expect {
          described_class.from_hash(
            "view_group" => "deals",
            "badge" => { "renderer" => "count_badge" }
          )
        }.to raise_error(LcpRuby::MetadataError, /requires a provider/)
      end

      it "raises when badge has no rendering form" do
        expect {
          described_class.from_hash(
            "view_group" => "deals",
            "badge" => { "provider" => "open_tasks" }
          )
        }.to raise_error(LcpRuby::MetadataError, /must have one of/)
      end

      it "raises when badge has multiple rendering forms" do
        expect {
          described_class.from_hash(
            "view_group" => "deals",
            "badge" => { "provider" => "open_tasks", "renderer" => "count_badge", "template" => "{value}" }
          )
        }.to raise_error(LcpRuby::MetadataError, /must have exactly one of/)
      end
    end
  end

  describe "type predicates" do
    it "view_group?" do
      item = described_class.from_hash("view_group" => "deals")
      expect(item.view_group?).to be true
      expect(item.link?).to be false
      expect(item.group?).to be false
      expect(item.separator?).to be false
    end

    it "link?" do
      item = described_class.from_hash("label" => "Home", "url" => "/home")
      expect(item.link?).to be true
    end

    it "group?" do
      item = described_class.from_hash("label" => "G", "children" => [ { "separator" => true } ])
      expect(item.group?).to be true
    end

    it "separator?" do
      item = described_class.from_hash("separator" => true)
      expect(item.separator?).to be true
    end
  end
end
