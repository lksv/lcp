require "spec_helper"

RSpec.describe LcpRuby::Metadata::MenuDefinition do
  describe ".from_hash" do
    it "parses top_menu only" do
      menu = described_class.from_hash(
        "menu" => {
          "top_menu" => [
            { "view_group" => "deals" },
            { "label" => "Home", "url" => "/home" }
          ]
        }
      )

      expect(menu.has_top_menu?).to be true
      expect(menu.has_sidebar_menu?).to be false
      expect(menu.top_only?).to be true
      expect(menu.sidebar_only?).to be false
      expect(menu.both?).to be false
      expect(menu.layout_mode).to eq("top")
      expect(menu.top_menu.length).to eq(2)
    end

    it "parses sidebar_menu only" do
      menu = described_class.from_hash(
        "menu" => {
          "sidebar_menu" => [
            { "view_group" => "deals" }
          ]
        }
      )

      expect(menu.has_top_menu?).to be false
      expect(menu.has_sidebar_menu?).to be true
      expect(menu.top_only?).to be false
      expect(menu.sidebar_only?).to be true
      expect(menu.both?).to be false
      expect(menu.layout_mode).to eq("sidebar")
    end

    it "parses both top_menu and sidebar_menu" do
      menu = described_class.from_hash(
        "menu" => {
          "top_menu" => [ { "view_group" => "deals" } ],
          "sidebar_menu" => [ { "view_group" => "companies" } ]
        }
      )

      expect(menu.has_top_menu?).to be true
      expect(menu.has_sidebar_menu?).to be true
      expect(menu.both?).to be true
      expect(menu.layout_mode).to eq("both")
    end

    it "parses nested groups" do
      menu = described_class.from_hash(
        "menu" => {
          "top_menu" => [
            {
              "label" => "CRM",
              "icon" => "briefcase",
              "children" => [
                { "view_group" => "deals" },
                { "separator" => true },
                { "label" => "Reports", "url" => "/reports" }
              ]
            }
          ]
        }
      )

      group = menu.top_menu.first
      expect(group.group?).to be true
      expect(group.children.length).to eq(3)
    end

    it "works without wrapping menu key" do
      menu = described_class.from_hash(
        "top_menu" => [ { "view_group" => "deals" } ]
      )

      expect(menu.has_top_menu?).to be true
      expect(menu.top_menu.length).to eq(1)
    end
  end

  describe "validation" do
    it "raises when neither top_menu nor sidebar_menu is present" do
      expect {
        described_class.new
      }.to raise_error(LcpRuby::MetadataError, /must have at least one of/)
    end
  end
end
