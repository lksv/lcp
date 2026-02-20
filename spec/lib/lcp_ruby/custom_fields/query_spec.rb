require "spec_helper"
require "support/integration_helper"

RSpec.describe LcpRuby::CustomFields::Query do
  before(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("custom_fields_test")
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("custom_fields_test")
  end

  before(:each) do
    Object.new.extend(IntegrationHelper).load_integration_metadata!("custom_fields_test")
    project_model.delete_all
  end

  let(:project_model) { LcpRuby.registry.model_for("project") }

  describe ".text_search" do
    it "finds records by custom field value" do
      p1 = project_model.create!(name: "P1")
      p1.write_custom_field("website", "https://example.com")
      p1.save!

      p2 = project_model.create!(name: "P2")
      p2.write_custom_field("website", "https://other.org")
      p2.save!

      result = described_class.text_search(
        project_model.all, "cf_projects", "website", "example"
      )

      expect(result.count).to eq(1)
      expect(result.first.name).to eq("P1")
    end

    it "returns empty when no match" do
      p1 = project_model.create!(name: "P1")
      p1.write_custom_field("website", "https://example.com")
      p1.save!

      result = described_class.text_search(
        project_model.all, "cf_projects", "website", "nonexistent"
      )

      expect(result.count).to eq(0)
    end
  end

  describe ".exact_match" do
    it "finds records with exact custom field value" do
      p1 = project_model.create!(name: "P1")
      p1.write_custom_field("status", "active")
      p1.save!

      p2 = project_model.create!(name: "P2")
      p2.write_custom_field("status", "inactive")
      p2.save!

      result = described_class.exact_match(
        project_model.all, "cf_projects", "status", "active"
      )

      expect(result.count).to eq(1)
      expect(result.first.name).to eq("P1")
    end
  end

  describe ".sort_expression" do
    it "returns a valid SQL expression for sorting" do
      expr = described_class.sort_expression("cf_projects", "website", "asc")
      expect(expr).to be_a(Arel::Nodes::SqlLiteral)
      expect(expr.to_s).to include("ASC")
    end

    it "handles desc direction" do
      expr = described_class.sort_expression("cf_projects", "website", "desc")
      expect(expr.to_s).to include("DESC")
    end
  end

  describe ".text_search_condition" do
    it "returns a SQL condition string" do
      condition = described_class.text_search_condition("cf_projects", "website", "test")
      expect(condition).to be_a(String)
      expect(condition).to include("custom_data")
      expect(condition).to include("website")
    end
  end

  describe "field name validation" do
    it "raises ArgumentError for field names with uppercase letters" do
      expect { described_class.text_search_condition("t", "BadName", "q") }
        .to raise_error(ArgumentError, /Invalid custom field name/)
    end

    it "raises ArgumentError for field names starting with a digit" do
      expect { described_class.exact_match(project_model.all, "t", "1field", "v") }
        .to raise_error(ArgumentError, /Invalid custom field name/)
    end

    it "raises ArgumentError for field names with special characters" do
      expect { described_class.sort_expression("t", "field-name", "asc") }
        .to raise_error(ArgumentError, /Invalid custom field name/)
    end

    it "raises ArgumentError for empty field names" do
      expect { described_class.text_search_condition("t", "", "q") }
        .to raise_error(ArgumentError, /Invalid custom field name/)
    end

    it "accepts valid field names" do
      expect { described_class.text_search_condition("cf_projects", "valid_name_123", "q") }
        .not_to raise_error
    end
  end
end
