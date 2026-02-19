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
        navigation_config: { "position" => 1 }
      )
    end

    let(:view_group_restricted) do
      instance_double(
        LcpRuby::Metadata::ViewGroupDefinition,
        primary_presenter: "project_public",
        presenter_names: [ "project_public" ],
        navigation_config: { "position" => 2 }
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
