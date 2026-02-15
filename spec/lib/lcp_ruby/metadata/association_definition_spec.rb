require "spec_helper"

RSpec.describe LcpRuby::Metadata::AssociationDefinition do
  describe "#initialize" do
    it "infers foreign_key for belongs_to from association name" do
      assoc = described_class.new(
        type: "belongs_to",
        name: "company",
        target_model: "company"
      )

      expect(assoc.foreign_key).to eq("company_id")
    end

    it "does not infer foreign_key for has_many" do
      assoc = described_class.new(
        type: "has_many",
        name: "deals",
        target_model: "deal"
      )

      expect(assoc.foreign_key).to be_nil
    end

    it "does not infer foreign_key for has_one" do
      assoc = described_class.new(
        type: "has_one",
        name: "profile",
        target_model: "profile"
      )

      expect(assoc.foreign_key).to be_nil
    end

    it "uses explicit foreign_key over inferred one" do
      assoc = described_class.new(
        type: "belongs_to",
        name: "company",
        target_model: "company",
        foreign_key: "org_id"
      )

      expect(assoc.foreign_key).to eq("org_id")
    end

    it "defaults required to true for belongs_to" do
      assoc = described_class.new(
        type: "belongs_to",
        name: "company",
        target_model: "company"
      )

      expect(assoc.required).to be true
    end

    it "defaults required to false for has_many" do
      assoc = described_class.new(
        type: "has_many",
        name: "deals",
        target_model: "deal"
      )

      expect(assoc.required).to be false
    end

    it "stores inverse_of as symbol" do
      assoc = described_class.new(
        type: "has_many", name: "tasks", target_model: "task", inverse_of: "project"
      )
      expect(assoc.inverse_of).to eq(:project)
    end

    it "stores counter_cache" do
      assoc = described_class.new(
        type: "belongs_to", name: "company", target_model: "company", counter_cache: true
      )
      expect(assoc.counter_cache).to be true
    end

    it "stores counter_cache with custom column name" do
      assoc = described_class.new(
        type: "belongs_to", name: "company", target_model: "company", counter_cache: "deals_count"
      )
      expect(assoc.counter_cache).to eq("deals_count")
    end

    it "stores touch" do
      assoc = described_class.new(
        type: "belongs_to", name: "project", target_model: "project", touch: true
      )
      expect(assoc.touch).to be true
    end

    it "defaults polymorphic to false" do
      assoc = described_class.new(
        type: "belongs_to", name: "company", target_model: "company"
      )
      expect(assoc.polymorphic).to be false
    end

    it "allows polymorphic belongs_to without target_model or class_name" do
      assoc = described_class.new(
        type: "belongs_to", name: "commentable", polymorphic: true
      )
      expect(assoc.polymorphic).to be true
      expect(assoc.target_model).to be_blank
    end

    it "stores as for has_many" do
      assoc = described_class.new(
        type: "has_many", name: "comments", target_model: "comment", as: "commentable"
      )
      expect(assoc.as).to eq("commentable")
    end

    it "allows has_many with as without target_model" do
      assoc = described_class.new(
        type: "has_many", name: "comments", as: "commentable"
      )
      expect(assoc.as).to eq("commentable")
    end

    it "stores through and source" do
      assoc = described_class.new(
        type: "has_many", name: "tags", through: "taggings", source: "tag"
      )
      expect(assoc.through).to eq("taggings")
      expect(assoc.source).to eq("tag")
    end

    it "allows has_many through without target_model" do
      assoc = described_class.new(
        type: "has_many", name: "tags", through: "taggings"
      )
      expect(assoc.through?).to be true
    end

    it "stores autosave" do
      assoc = described_class.new(
        type: "has_many", name: "items", target_model: "item", autosave: true
      )
      expect(assoc.autosave).to be true
    end

    it "stores validate" do
      assoc = described_class.new(
        type: "has_many", name: "items", target_model: "item", validate: false
      )
      expect(assoc.validate).to be false
    end
  end

  describe "#through?" do
    it "returns true when through is set" do
      assoc = described_class.new(
        type: "has_many", name: "tags", through: "taggings"
      )
      expect(assoc.through?).to be true
    end

    it "returns false when through is not set" do
      assoc = described_class.new(
        type: "has_many", name: "tasks", target_model: "task"
      )
      expect(assoc.through?).to be false
    end
  end

  describe "validation" do
    it "raises for invalid type" do
      expect {
        described_class.new(type: "invalid", name: "x", target_model: "y")
      }.to raise_error(LcpRuby::MetadataError, /invalid/)
    end

    it "raises for blank name" do
      expect {
        described_class.new(type: "belongs_to", name: "", target_model: "y")
      }.to raise_error(LcpRuby::MetadataError, /name is required/)
    end

    it "raises when no target_model, class_name, polymorphic, as, or through" do
      expect {
        described_class.new(type: "belongs_to", name: "company")
      }.to raise_error(LcpRuby::MetadataError, /requires target_model/)
    end

    it "does not raise for polymorphic belongs_to" do
      expect {
        described_class.new(type: "belongs_to", name: "commentable", polymorphic: true)
      }.not_to raise_error
    end

    it "does not raise for has_many with as" do
      expect {
        described_class.new(type: "has_many", name: "comments", as: "commentable")
      }.not_to raise_error
    end

    it "does not raise for has_many through" do
      expect {
        described_class.new(type: "has_many", name: "tags", through: "taggings")
      }.not_to raise_error
    end
  end

  describe ".from_hash" do
    it "infers foreign_key for belongs_to when not specified in hash" do
      assoc = described_class.from_hash(
        "type" => "belongs_to",
        "name" => "project",
        "target_model" => "project"
      )

      expect(assoc.foreign_key).to eq("project_id")
    end

    it "reads all Tier 1 options from hash" do
      assoc = described_class.from_hash(
        "type" => "belongs_to",
        "name" => "project",
        "target_model" => "project",
        "inverse_of" => "tasks",
        "counter_cache" => true,
        "touch" => true
      )

      expect(assoc.inverse_of).to eq(:tasks)
      expect(assoc.counter_cache).to be true
      expect(assoc.touch).to be true
    end

    it "reads polymorphic and as from hash" do
      assoc = described_class.from_hash(
        "type" => "belongs_to",
        "name" => "commentable",
        "polymorphic" => true
      )

      expect(assoc.polymorphic).to be true
    end

    it "reads through and source from hash" do
      assoc = described_class.from_hash(
        "type" => "has_many",
        "name" => "tags",
        "through" => "taggings",
        "source" => "tag"
      )

      expect(assoc.through).to eq("taggings")
      expect(assoc.source).to eq("tag")
    end

    it "reads autosave and validate from hash" do
      assoc = described_class.from_hash(
        "type" => "has_many",
        "name" => "items",
        "target_model" => "item",
        "autosave" => true,
        "validate" => false
      )

      expect(assoc.autosave).to be true
      expect(assoc.validate).to be false
    end
  end
end
