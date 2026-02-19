require "spec_helper"

RSpec.describe LcpRuby::ModelFactory::AssociationApplicator do
  # Use a fresh anonymous class for each test to avoid state leakage
  let(:model_class) { Class.new(ActiveRecord::Base) { self.abstract_class = true } }

  describe "order scope" do
    it "applies order scope lambda to has_many when order is present" do
      assoc = LcpRuby::Metadata::AssociationDefinition.new(
        type: "has_many", name: "items", target_model: "item",
        order: { "position" => "asc" }
      )
      model_def = instance_double(LcpRuby::Metadata::ModelDefinition, associations: [ assoc ])

      expect(model_class).to receive(:has_many).with(:items, kind_of(Proc), hash_including)

      described_class.new(model_class, model_def).apply!
    end

    it "does not apply order scope when order is nil" do
      assoc = LcpRuby::Metadata::AssociationDefinition.new(
        type: "has_many", name: "items", target_model: "item"
      )
      model_def = instance_double(LcpRuby::Metadata::ModelDefinition, associations: [ assoc ])

      expect(model_class).to receive(:has_many).with(:items, hash_including)

      described_class.new(model_class, model_def).apply!
    end

    it "applies order scope lambda to has_one when order is present" do
      assoc = LcpRuby::Metadata::AssociationDefinition.new(
        type: "has_one", name: "latest_item", target_model: "item",
        order: { "created_at" => "desc" }
      )
      model_def = instance_double(LcpRuby::Metadata::ModelDefinition, associations: [ assoc ])

      expect(model_class).to receive(:has_one).with(:latest_item, kind_of(Proc), hash_including)

      described_class.new(model_class, model_def).apply!
    end
  end

  describe "#apply_nested_attributes" do
    it "calls accepts_nested_attributes_for with allow_destroy" do
      assoc = LcpRuby::Metadata::AssociationDefinition.new(
        type: "has_many", name: "items", target_model: "item",
        inverse_of: "order",
        nested_attributes: { "allow_destroy" => true }
      )
      model_def = instance_double(LcpRuby::Metadata::ModelDefinition, associations: [ assoc ])

      expect(model_class).to receive(:has_many)
      expect(model_class).to receive(:accepts_nested_attributes_for)
        .with(:items, allow_destroy: true)

      described_class.new(model_class, model_def).apply!
    end

    it "calls accepts_nested_attributes_for with reject_if :all_blank" do
      assoc = LcpRuby::Metadata::AssociationDefinition.new(
        type: "has_many", name: "items", target_model: "item",
        nested_attributes: { "reject_if" => "all_blank" }
      )
      model_def = instance_double(LcpRuby::Metadata::ModelDefinition, associations: [ assoc ])

      expect(model_class).to receive(:has_many)
      expect(model_class).to receive(:accepts_nested_attributes_for)
        .with(:items, reject_if: :all_blank)

      described_class.new(model_class, model_def).apply!
    end

    it "calls accepts_nested_attributes_for with limit" do
      assoc = LcpRuby::Metadata::AssociationDefinition.new(
        type: "has_many", name: "items", target_model: "item",
        nested_attributes: { "limit" => 50 }
      )
      model_def = instance_double(LcpRuby::Metadata::ModelDefinition, associations: [ assoc ])

      expect(model_class).to receive(:has_many)
      expect(model_class).to receive(:accepts_nested_attributes_for)
        .with(:items, limit: 50)

      described_class.new(model_class, model_def).apply!
    end

    it "calls accepts_nested_attributes_for with update_only" do
      assoc = LcpRuby::Metadata::AssociationDefinition.new(
        type: "has_one", name: "profile", target_model: "profile",
        nested_attributes: { "update_only" => true }
      )
      model_def = instance_double(LcpRuby::Metadata::ModelDefinition, associations: [ assoc ])

      expect(model_class).to receive(:has_one)
      expect(model_class).to receive(:accepts_nested_attributes_for)
        .with(:profile, update_only: true)

      described_class.new(model_class, model_def).apply!
    end

    it "calls accepts_nested_attributes_for with all options combined" do
      assoc = LcpRuby::Metadata::AssociationDefinition.new(
        type: "has_many", name: "items", target_model: "item",
        nested_attributes: {
          "allow_destroy" => true,
          "reject_if" => "all_blank",
          "limit" => 10,
          "update_only" => false
        }
      )
      model_def = instance_double(LcpRuby::Metadata::ModelDefinition, associations: [ assoc ])

      expect(model_class).to receive(:has_many)
      expect(model_class).to receive(:accepts_nested_attributes_for)
        .with(:items, allow_destroy: true, reject_if: :all_blank, limit: 10, update_only: false)

      described_class.new(model_class, model_def).apply!
    end

    it "does not call accepts_nested_attributes_for when nested_attributes is nil" do
      assoc = LcpRuby::Metadata::AssociationDefinition.new(
        type: "has_many", name: "items", target_model: "item"
      )
      model_def = instance_double(LcpRuby::Metadata::ModelDefinition, associations: [ assoc ])

      expect(model_class).to receive(:has_many)
      expect(model_class).not_to receive(:accepts_nested_attributes_for)

      described_class.new(model_class, model_def).apply!
    end

    it "converts custom reject_if string to symbol" do
      assoc = LcpRuby::Metadata::AssociationDefinition.new(
        type: "has_many", name: "items", target_model: "item",
        nested_attributes: { "reject_if" => "custom_method" }
      )
      model_def = instance_double(LcpRuby::Metadata::ModelDefinition, associations: [ assoc ])

      expect(model_class).to receive(:has_many)
      expect(model_class).to receive(:accepts_nested_attributes_for)
        .with(:items, reject_if: :custom_method)

      described_class.new(model_class, model_def).apply!
    end

    it "applies nested_attributes for has_one associations" do
      assoc = LcpRuby::Metadata::AssociationDefinition.new(
        type: "has_one", name: "address", target_model: "address",
        nested_attributes: { "allow_destroy" => false, "update_only" => true }
      )
      model_def = instance_double(LcpRuby::Metadata::ModelDefinition, associations: [ assoc ])

      expect(model_class).to receive(:has_one)
      expect(model_class).to receive(:accepts_nested_attributes_for)
        .with(:address, allow_destroy: false, update_only: true)

      described_class.new(model_class, model_def).apply!
    end

    it "does not apply nested_attributes for belongs_to" do
      assoc = LcpRuby::Metadata::AssociationDefinition.new(
        type: "belongs_to", name: "company", target_model: "company",
        nested_attributes: { "allow_destroy" => true }
      )
      model_def = instance_double(LcpRuby::Metadata::ModelDefinition, associations: [ assoc ])

      expect(model_class).to receive(:belongs_to)
      expect(model_class).not_to receive(:accepts_nested_attributes_for)

      described_class.new(model_class, model_def).apply!
    end
  end
end
