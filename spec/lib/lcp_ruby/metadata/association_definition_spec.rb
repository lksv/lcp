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
  end
end
