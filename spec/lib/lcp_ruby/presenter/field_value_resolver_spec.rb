require "spec_helper"

RSpec.describe LcpRuby::Presenter::FieldValueResolver do
  let(:company_model_def) do
    LcpRuby::Metadata::ModelDefinition.from_hash(
      "name" => "company",
      "fields" => [
        { "name" => "name", "type" => "string" },
        { "name" => "industry", "type" => "string" }
      ],
      "associations" => [
        { "type" => "has_many", "name" => "contacts", "target_model" => "contact", "foreign_key" => "company_id" }
      ]
    )
  end

  let(:contact_model_def) do
    LcpRuby::Metadata::ModelDefinition.from_hash(
      "name" => "contact",
      "fields" => [
        { "name" => "first_name", "type" => "string" },
        { "name" => "email", "type" => "string" }
      ],
      "associations" => [
        { "type" => "belongs_to", "name" => "company", "target_model" => "company", "foreign_key" => "company_id" }
      ]
    )
  end

  let(:deal_model_def) do
    LcpRuby::Metadata::ModelDefinition.from_hash(
      "name" => "deal",
      "fields" => [
        { "name" => "title", "type" => "string" },
        { "name" => "value", "type" => "decimal" }
      ],
      "associations" => [
        { "type" => "belongs_to", "name" => "company", "target_model" => "company", "foreign_key" => "company_id" },
        { "type" => "belongs_to", "name" => "contact", "target_model" => "contact", "foreign_key" => "contact_id" }
      ]
    )
  end

  let(:default_perm_def) do
    LcpRuby::Metadata::PermissionDefinition.from_hash(
      "model" => "_default",
      "default_role" => "admin",
      "roles" => {
        "admin" => {
          "crud" => %w[index show create update delete],
          "fields" => { "readable" => "all", "writable" => "all" }
        }
      }
    )
  end

  let(:restricted_perm_def) do
    LcpRuby::Metadata::PermissionDefinition.from_hash(
      "model" => "company",
      "default_role" => "admin",
      "roles" => {
        "admin" => {
          "crud" => %w[index show create update delete],
          "fields" => { "readable" => "all", "writable" => "all" }
        },
        "restricted" => {
          "crud" => %w[index show],
          "fields" => { "readable" => %w[name], "writable" => [] }
        }
      }
    )
  end

  let(:admin_user) { double("User", lcp_role: "admin") }
  let(:restricted_user) { double("User", lcp_role: "restricted") }

  let(:admin_evaluator) do
    LcpRuby::Authorization::PermissionEvaluator.new(default_perm_def, admin_user, "deal")
  end

  let(:resolver) { described_class.new(deal_model_def, admin_evaluator) }

  before do
    allow(LcpRuby).to receive(:loader).and_return(
      double("Loader").tap do |loader|
        allow(loader).to receive(:model_definition) do |name|
          case name.to_s
          when "deal" then deal_model_def
          when "company" then company_model_def
          when "contact" then contact_model_def
          else raise LcpRuby::MetadataError, "Model '#{name}' not found"
          end
        end
        allow(loader).to receive(:permission_definition) do |name|
          case name.to_s
          when "company" then restricted_perm_def
          else default_perm_def
          end
        end
      end
    )
  end

  describe ".dot_path?" do
    it "returns true for dot-notation fields" do
      expect(described_class.dot_path?("company.name")).to be true
    end

    it "returns false for simple fields" do
      expect(described_class.dot_path?("title")).to be false
    end

    it "returns false for template fields" do
      expect(described_class.dot_path?("{company.name}")).to be false
    end
  end

  describe ".template_field?" do
    it "returns true for template fields" do
      expect(described_class.template_field?("{company.name}: {title}")).to be true
    end

    it "returns false for dot-path fields" do
      expect(described_class.template_field?("company.name")).to be false
    end

    it "returns false for simple fields" do
      expect(described_class.template_field?("title")).to be false
    end
  end

  describe "#resolve" do
    context "simple field" do
      it "resolves a simple field value" do
        record = double("Record", title: "Big Deal")
        allow(record).to receive(:respond_to?).with("title").and_return(true)

        expect(resolver.resolve(record, "title")).to eq("Big Deal")
      end

      it "returns nil for unknown field" do
        record = double("Record")
        allow(record).to receive(:respond_to?).with("nonexistent").and_return(false)

        expect(resolver.resolve(record, "nonexistent")).to be_nil
      end
    end

    context "FK field" do
      let(:company_assoc) do
        deal_model_def.associations.find { |a| a.name == "company" }
      end

      it "resolves FK via association to_label" do
        company = double("Company")
        allow(company).to receive(:respond_to?).with(:to_label).and_return(true)
        allow(company).to receive(:to_label).and_return("Acme Corp")

        record = double("Record")
        allow(record).to receive(:respond_to?).with("company").and_return(true)
        allow(record).to receive(:company).and_return(company)

        fk_map = { "company_id" => company_assoc }
        expect(resolver.resolve(record, "company_id", fk_map: fk_map)).to eq("Acme Corp")
      end

      it "returns nil when FK association is nil" do
        record = double("Record")
        allow(record).to receive(:respond_to?).with("company").and_return(true)
        allow(record).to receive(:company).and_return(nil)

        fk_map = { "company_id" => company_assoc }
        expect(resolver.resolve(record, "company_id", fk_map: fk_map)).to be_nil
      end
    end

    context "dot-path belongs_to" do
      it "resolves belongs_to dot-path" do
        company = double("Company")
        allow(company).to receive(:respond_to?).with("name").and_return(true)
        allow(company).to receive(:name).and_return("Acme Corp")

        record = double("Record")
        allow(record).to receive(:respond_to?).with("company").and_return(true)
        allow(record).to receive(:company).and_return(company)

        expect(resolver.resolve(record, "company.name")).to eq("Acme Corp")
      end

      it "returns nil when intermediate association is nil" do
        record = double("Record")
        allow(record).to receive(:respond_to?).with("company").and_return(true)
        allow(record).to receive(:company).and_return(nil)

        expect(resolver.resolve(record, "company.name")).to be_nil
      end

      it "returns nil when target field is not readable" do
        # restricted user can only read 'name', not 'industry'
        restricted_evaluator = LcpRuby::Authorization::PermissionEvaluator.new(
          default_perm_def, restricted_user, "deal"
        )
        restricted_resolver = described_class.new(deal_model_def, restricted_evaluator)

        company = double("Company")
        allow(company).to receive(:respond_to?).with("industry").and_return(true)
        allow(company).to receive(:industry).and_return("Technology")

        record = double("Record")
        allow(record).to receive(:respond_to?).with("company").and_return(true)
        allow(record).to receive(:company).and_return(company)

        # industry is not in restricted role's readable fields for company
        expect(restricted_resolver.resolve(record, "company.industry")).to be_nil
      end
    end

    context "dot-path has_many" do
      it "resolves has_many dot-path to array" do
        company_resolver = described_class.new(company_model_def, admin_evaluator)

        contact1 = double("Contact1")
        allow(contact1).to receive(:respond_to?).with("first_name").and_return(true)
        allow(contact1).to receive(:first_name).and_return("Alice")

        contact2 = double("Contact2")
        allow(contact2).to receive(:respond_to?).with("first_name").and_return(true)
        allow(contact2).to receive(:first_name).and_return("Bob")

        contacts = [ contact1, contact2 ]
        record = double("CompanyRecord")
        allow(record).to receive(:respond_to?).with("contacts").and_return(true)
        allow(record).to receive(:contacts).and_return(contacts)

        result = company_resolver.resolve(record, "contacts.first_name")
        expect(result).to eq([ "Alice", "Bob" ])
      end
    end

    context "template" do
      it "resolves template with simple fields" do
        record = double("Record")
        allow(record).to receive(:respond_to?).with("title").and_return(true)
        allow(record).to receive(:title).and_return("Big Deal")
        allow(record).to receive(:respond_to?).with("value").and_return(true)
        allow(record).to receive(:value).and_return(500)

        expect(resolver.resolve(record, "{title}: {value}")).to eq("Big Deal: 500")
      end

      it "resolves template with dot-path" do
        company = double("Company")
        allow(company).to receive(:respond_to?).with("name").and_return(true)
        allow(company).to receive(:name).and_return("Acme")

        record = double("Record")
        allow(record).to receive(:respond_to?).with("company").and_return(true)
        allow(record).to receive(:company).and_return(company)
        allow(record).to receive(:respond_to?).with("title").and_return(true)
        allow(record).to receive(:title).and_return("Big Deal")

        expect(resolver.resolve(record, "{company.name}: {title}")).to eq("Acme: Big Deal")
      end
    end

    context "blank field_path" do
      it "returns nil" do
        record = double("Record")
        expect(resolver.resolve(record, "")).to be_nil
        expect(resolver.resolve(record, nil)).to be_nil
      end
    end
  end
end
