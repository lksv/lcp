require "spec_helper"

RSpec.describe LcpRuby::Metadata::DisplayTemplateDefinition do
  describe ".from_hash" do
    it "parses a structured template" do
      defn = described_class.from_hash("default", {
        "template" => "{first_name} {last_name}",
        "subtitle" => "{position} at {company.name}",
        "icon" => "user",
        "badge" => "{status}"
      })

      expect(defn.name).to eq("default")
      expect(defn.template).to eq("{first_name} {last_name}")
      expect(defn.subtitle).to eq("{position} at {company.name}")
      expect(defn.icon).to eq("user")
      expect(defn.badge).to eq("{status}")
      expect(defn.options).to eq({})
    end

    it "parses a renderer template" do
      defn = described_class.from_hash("card", {
        "renderer" => "ContactCardRenderer",
        "options" => { "size" => "large" }
      })

      expect(defn.name).to eq("card")
      expect(defn.renderer).to eq("ContactCardRenderer")
      expect(defn.options).to eq({ "size" => "large" })
    end

    it "parses a partial template" do
      defn = described_class.from_hash("mini", {
        "partial" => "contacts/mini_label"
      })

      expect(defn.name).to eq("mini")
      expect(defn.partial).to eq("contacts/mini_label")
    end
  end

  describe "#form" do
    it "returns :structured for template-based definitions" do
      defn = described_class.from_hash("default", { "template" => "{name}" })

      expect(defn.form).to eq(:structured)
    end

    it "returns :renderer when renderer is present" do
      defn = described_class.from_hash("card", { "renderer" => "CardRenderer" })

      expect(defn.form).to eq(:renderer)
    end

    it "returns :partial when partial is present" do
      defn = described_class.from_hash("mini", { "partial" => "contacts/mini" })

      expect(defn.form).to eq(:partial)
    end

    it "prefers renderer over template" do
      defn = described_class.from_hash("mixed", {
        "template" => "{name}",
        "renderer" => "MixedRenderer"
      })

      expect(defn.form).to eq(:renderer)
    end
  end

  describe "predicates" do
    it "#structured? returns true for structured form" do
      defn = described_class.from_hash("default", { "template" => "{name}" })

      expect(defn).to be_structured
      expect(defn).not_to be_renderer
      expect(defn).not_to be_partial
    end

    it "#renderer? returns true for renderer form" do
      defn = described_class.from_hash("card", { "renderer" => "CardRenderer" })

      expect(defn).to be_renderer
      expect(defn).not_to be_structured
      expect(defn).not_to be_partial
    end

    it "#partial? returns true for partial form" do
      defn = described_class.from_hash("mini", { "partial" => "mini" })

      expect(defn).to be_partial
      expect(defn).not_to be_structured
      expect(defn).not_to be_renderer
    end
  end

  describe "#referenced_fields" do
    it "extracts simple field references" do
      defn = described_class.from_hash("default", {
        "template" => "{first_name} {last_name}"
      })

      expect(defn.referenced_fields).to contain_exactly("first_name", "last_name")
    end

    it "extracts dot-path references from subtitle" do
      defn = described_class.from_hash("default", {
        "template" => "{name}",
        "subtitle" => "{company.name}"
      })

      expect(defn.referenced_fields).to contain_exactly("name", "company.name")
    end

    it "extracts from template, subtitle, and badge" do
      defn = described_class.from_hash("default", {
        "template" => "{first_name}",
        "subtitle" => "{position}",
        "badge" => "{status}"
      })

      expect(defn.referenced_fields).to contain_exactly("first_name", "position", "status")
    end

    it "deduplicates field references" do
      defn = described_class.from_hash("default", {
        "template" => "{name}",
        "subtitle" => "{name} details"
      })

      expect(defn.referenced_fields).to eq([ "name" ])
    end

    it "returns empty array for renderer template" do
      defn = described_class.from_hash("card", { "renderer" => "CardRenderer" })

      expect(defn.referenced_fields).to eq([])
    end

    it "returns empty array for partial template" do
      defn = described_class.from_hash("mini", { "partial" => "mini" })

      expect(defn.referenced_fields).to eq([])
    end
  end

  describe "validation" do
    it "raises on missing name" do
      expect {
        described_class.from_hash("", { "template" => "{name}" })
      }.to raise_error(LcpRuby::MetadataError, /name is required/)
    end

    it "raises when no template, renderer, or partial is provided" do
      expect {
        described_class.from_hash("bad", { "icon" => "user" })
      }.to raise_error(LcpRuby::MetadataError, /must have template, renderer, or partial/)
    end
  end
end
