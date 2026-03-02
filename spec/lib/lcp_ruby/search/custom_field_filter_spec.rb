require "spec_helper"
require "support/integration_helper"

RSpec.describe LcpRuby::Search::CustomFieldFilter do
  include IntegrationHelper

  # Use a real DB-backed model with a custom_data JSON column for testing
  before(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.load_integration_metadata!("advanced_search")
  end

  after(:all) do
    helper = Object.new.extend(IntegrationHelper)
    helper.teardown_integration_tables!("advanced_search")
  end

  before(:each) do
    load_integration_metadata!("advanced_search")
    product_model.delete_all
  end

  let(:product_model) { LcpRuby.registry.model_for("product") }
  let(:table_name) { product_model.table_name }

  # Helper to create a product with custom_data
  def create_product(name:, custom_data: {})
    product_model.create!(name: name, custom_data: custom_data)
  end

  describe ".apply" do
    context "eq operator" do
      it "filters by exact match" do
        create_product(name: "A", custom_data: { "color" => "red" })
        create_product(name: "B", custom_data: { "color" => "blue" })

        scope = described_class.apply(product_model.all, table_name, "color", :eq, "red")
        expect(scope.map(&:name)).to eq(["A"])
      end
    end

    context "not_eq operator" do
      it "excludes matching records and includes NULLs" do
        create_product(name: "A", custom_data: { "color" => "red" })
        create_product(name: "B", custom_data: { "color" => "blue" })
        create_product(name: "C", custom_data: {})

        scope = described_class.apply(product_model.all, table_name, "color", :not_eq, "red")
        names = scope.map(&:name).sort
        expect(names).to include("B")
        expect(names).to include("C")
        expect(names).not_to include("A")
      end
    end

    context "cont operator" do
      it "filters by substring match" do
        create_product(name: "A", custom_data: { "desc" => "hello world" })
        create_product(name: "B", custom_data: { "desc" => "goodbye" })

        scope = described_class.apply(product_model.all, table_name, "desc", :cont, "world")
        expect(scope.map(&:name)).to eq(["A"])
      end
    end

    context "not_cont operator" do
      it "excludes substring matches and includes NULLs" do
        create_product(name: "A", custom_data: { "desc" => "hello world" })
        create_product(name: "B", custom_data: { "desc" => "goodbye" })
        create_product(name: "C", custom_data: {})

        scope = described_class.apply(product_model.all, table_name, "desc", :not_cont, "world")
        names = scope.map(&:name).sort
        expect(names).to include("B", "C")
        expect(names).not_to include("A")
      end
    end

    context "start operator" do
      it "filters by prefix" do
        create_product(name: "A", custom_data: { "code" => "ABC-123" })
        create_product(name: "B", custom_data: { "code" => "XYZ-789" })

        scope = described_class.apply(product_model.all, table_name, "code", :start, "ABC")
        expect(scope.map(&:name)).to eq(["A"])
      end
    end

    context "end operator" do
      it "filters by suffix" do
        create_product(name: "A", custom_data: { "code" => "ABC-123" })
        create_product(name: "B", custom_data: { "code" => "XYZ-789" })

        scope = described_class.apply(product_model.all, table_name, "code", :end, "789")
        expect(scope.map(&:name)).to eq(["B"])
      end
    end

    context "gt/gteq/lt/lteq operators with type casting" do
      it "filters with gt using integer cast" do
        create_product(name: "A", custom_data: { "qty" => "10" })
        create_product(name: "B", custom_data: { "qty" => "20" })
        create_product(name: "C", custom_data: { "qty" => "5" })

        scope = described_class.apply(product_model.all, table_name, "qty", :gt, "10", cast: :integer)
        expect(scope.map(&:name)).to eq(["B"])
      end

      it "filters with gteq" do
        create_product(name: "A", custom_data: { "qty" => "10" })
        create_product(name: "B", custom_data: { "qty" => "20" })

        scope = described_class.apply(product_model.all, table_name, "qty", :gteq, "10", cast: :integer)
        names = scope.map(&:name).sort
        expect(names).to eq(["A", "B"])
      end

      it "filters with lt" do
        create_product(name: "A", custom_data: { "qty" => "10" })
        create_product(name: "B", custom_data: { "qty" => "20" })

        scope = described_class.apply(product_model.all, table_name, "qty", :lt, "15", cast: :integer)
        expect(scope.map(&:name)).to eq(["A"])
      end

      it "filters with lteq" do
        create_product(name: "A", custom_data: { "qty" => "10" })
        create_product(name: "B", custom_data: { "qty" => "20" })

        scope = described_class.apply(product_model.all, table_name, "qty", :lteq, "10", cast: :integer)
        expect(scope.map(&:name)).to eq(["A"])
      end
    end

    context "between operator" do
      it "filters within range" do
        create_product(name: "A", custom_data: { "qty" => "5" })
        create_product(name: "B", custom_data: { "qty" => "15" })
        create_product(name: "C", custom_data: { "qty" => "25" })

        scope = described_class.apply(product_model.all, table_name, "qty", :between, ["10", "20"], cast: :integer)
        expect(scope.map(&:name)).to eq(["B"])
      end
    end

    context "in operator" do
      it "filters for values in a list" do
        create_product(name: "A", custom_data: { "color" => "red" })
        create_product(name: "B", custom_data: { "color" => "blue" })
        create_product(name: "C", custom_data: { "color" => "green" })

        scope = described_class.apply(product_model.all, table_name, "color", :in, ["red", "green"])
        names = scope.map(&:name).sort
        expect(names).to eq(["A", "C"])
      end
    end

    context "not_in operator" do
      it "excludes values in a list and includes NULLs" do
        create_product(name: "A", custom_data: { "color" => "red" })
        create_product(name: "B", custom_data: { "color" => "blue" })
        create_product(name: "C", custom_data: {})

        scope = described_class.apply(product_model.all, table_name, "color", :not_in, ["red"])
        names = scope.map(&:name).sort
        expect(names).to include("B", "C")
        expect(names).not_to include("A")
      end
    end

    context "present operator" do
      it "returns records where field has non-empty value" do
        create_product(name: "A", custom_data: { "color" => "red" })
        create_product(name: "B", custom_data: { "color" => "" })
        create_product(name: "C", custom_data: {})

        scope = described_class.apply(product_model.all, table_name, "color", :present, nil)
        expect(scope.map(&:name)).to eq(["A"])
      end
    end

    context "blank operator" do
      it "returns records where field is NULL or empty" do
        create_product(name: "A", custom_data: { "color" => "red" })
        create_product(name: "B", custom_data: { "color" => "" })
        create_product(name: "C", custom_data: {})

        scope = described_class.apply(product_model.all, table_name, "color", :blank, nil)
        names = scope.map(&:name).sort
        expect(names).to include("B", "C")
        expect(names).not_to include("A")
      end
    end

    context "null operator" do
      it "returns records where JSON key is absent" do
        create_product(name: "A", custom_data: { "color" => "red" })
        create_product(name: "B", custom_data: {})

        scope = described_class.apply(product_model.all, table_name, "color", :null, nil)
        expect(scope.map(&:name)).to eq(["B"])
      end
    end

    context "not_null operator" do
      it "returns records where JSON key exists" do
        create_product(name: "A", custom_data: { "color" => "red" })
        create_product(name: "B", custom_data: {})

        scope = described_class.apply(product_model.all, table_name, "color", :not_null, nil)
        expect(scope.map(&:name)).to eq(["A"])
      end
    end

    context "true operator" do
      it "returns records where value is 'true'" do
        create_product(name: "A", custom_data: { "vip" => "true" })
        create_product(name: "B", custom_data: { "vip" => "false" })

        scope = described_class.apply(product_model.all, table_name, "vip", :true, nil)
        expect(scope.map(&:name)).to eq(["A"])
      end
    end

    context "false operator" do
      it "returns records where value is 'false' or NULL" do
        create_product(name: "A", custom_data: { "vip" => "true" })
        create_product(name: "B", custom_data: { "vip" => "false" })
        create_product(name: "C", custom_data: {})

        scope = described_class.apply(product_model.all, table_name, "vip", :false, nil)
        names = scope.map(&:name).sort
        expect(names).to include("B", "C")
        expect(names).not_to include("A")
      end
    end
  end

  describe "input validation" do
    it "raises ArgumentError for invalid field names" do
      expect {
        described_class.apply(product_model.all, table_name, "1invalid", :eq, "x")
      }.to raise_error(ArgumentError, /Invalid custom field name/)
    end

    it "returns scope unchanged for unknown operators" do
      create_product(name: "A", custom_data: { "color" => "red" })

      scope = described_class.apply(product_model.all, table_name, "color", :unknown_op, "x")
      expect(scope.map(&:name)).to eq(["A"])
    end
  end

  describe ".cast_for_type" do
    it "returns :integer for integer type" do
      expect(described_class.cast_for_type("integer")).to eq(:integer)
    end

    it "returns :decimal for float type" do
      expect(described_class.cast_for_type("float")).to eq(:decimal)
    end

    it "returns :decimal for decimal type" do
      expect(described_class.cast_for_type("decimal")).to eq(:decimal)
    end

    it "returns :date for date type" do
      expect(described_class.cast_for_type("date")).to eq(:date)
    end

    it "returns nil for string type" do
      expect(described_class.cast_for_type("string")).to be_nil
    end
  end

  describe "LIKE pattern sanitization" do
    it "escapes special characters in LIKE patterns" do
      create_product(name: "A", custom_data: { "code" => "100% done" })
      create_product(name: "B", custom_data: { "code" => "normal" })

      scope = described_class.apply(product_model.all, table_name, "code", :cont, "100%")
      expect(scope.map(&:name)).to eq(["A"])
    end
  end
end
