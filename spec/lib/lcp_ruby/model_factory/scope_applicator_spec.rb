require "spec_helper"

RSpec.describe LcpRuby::ModelFactory::ScopeApplicator do
  after do
    ActiveRecord::Base.connection.drop_table(:contacts) if ActiveRecord::Base.connection.table_exists?(:contacts)
  end

  def build_model(model_hash)
    model_definition = LcpRuby::Metadata::ModelDefinition.from_hash(model_hash)
    LcpRuby::ModelFactory::SchemaManager.new(model_definition).ensure_table!
    LcpRuby::ModelFactory::Builder.new(model_definition).build
  end

  describe "where scopes" do
    context "with equality conditions" do
      let(:model_class) do
        build_model(
          "name" => "contact",
          "fields" => [
            { "name" => "name", "type" => "string" },
            { "name" => "status", "type" => "string" }
          ],
          "scopes" => [
            { "name" => "active", "where" => { "status" => "active" } }
          ],
          "options" => { "timestamps" => false }
        )
      end

      it "returns records matching the condition" do
        model_class.create!(name: "Alice", status: "active")
        model_class.create!(name: "Bob", status: "inactive")

        results = model_class.active
        expect(results.map(&:name)).to eq([ "Alice" ])
      end
    end

    context "with null condition" do
      let(:model_class) do
        build_model(
          "name" => "contact",
          "fields" => [
            { "name" => "name", "type" => "string" },
            { "name" => "phone", "type" => "string" }
          ],
          "scopes" => [
            { "name" => "without_phone", "where" => { "phone" => nil } }
          ],
          "options" => { "timestamps" => false }
        )
      end

      it "returns records where the field IS NULL" do
        model_class.create!(name: "Alice", phone: nil)
        model_class.create!(name: "Bob", phone: "555-1234")

        results = model_class.without_phone
        expect(results.map(&:name)).to eq([ "Alice" ])
      end
    end

    context "with array including null condition" do
      let(:model_class) do
        build_model(
          "name" => "contact",
          "fields" => [
            { "name" => "name", "type" => "string" },
            { "name" => "phone", "type" => "string" }
          ],
          "scopes" => [
            { "name" => "blank_phone", "where" => { "phone" => [ nil, "" ] } }
          ],
          "options" => { "timestamps" => false }
        )
      end

      it "returns records where the field IS NULL or empty string" do
        model_class.create!(name: "Alice", phone: nil)
        model_class.create!(name: "Bob", phone: "")
        model_class.create!(name: "Carol", phone: "555-1234")

        results = model_class.blank_phone
        expect(results.map(&:name)).to contain_exactly("Alice", "Bob")
      end
    end
  end

  describe "where_not scopes" do
    context "with null condition" do
      let(:model_class) do
        build_model(
          "name" => "contact",
          "fields" => [
            { "name" => "name", "type" => "string" },
            { "name" => "phone", "type" => "string" }
          ],
          "scopes" => [
            { "name" => "with_phone", "where_not" => { "phone" => nil } }
          ],
          "options" => { "timestamps" => false }
        )
      end

      it "returns records where the field IS NOT NULL" do
        model_class.create!(name: "Alice", phone: nil)
        model_class.create!(name: "Bob", phone: "555-1234")

        results = model_class.with_phone
        expect(results.map(&:name)).to eq([ "Bob" ])
      end
    end
  end

  describe "order scopes" do
    let(:model_class) do
      build_model(
        "name" => "contact",
        "fields" => [
          { "name" => "name", "type" => "string" },
          { "name" => "priority", "type" => "integer" }
        ],
        "scopes" => [
          { "name" => "by_priority", "order" => { "priority" => "desc" } }
        ],
        "options" => { "timestamps" => false }
      )
    end

    it "returns records in the specified order" do
      model_class.create!(name: "Low", priority: 1)
      model_class.create!(name: "High", priority: 10)
      model_class.create!(name: "Mid", priority: 5)

      results = model_class.by_priority
      expect(results.map(&:name)).to eq([ "High", "Mid", "Low" ])
    end
  end

  describe "limit scopes" do
    let(:model_class) do
      build_model(
        "name" => "contact",
        "fields" => [
          { "name" => "name", "type" => "string" }
        ],
        "scopes" => [
          { "name" => "first_two", "order" => { "id" => "asc" }, "limit" => 2 }
        ],
        "options" => { "timestamps" => false }
      )
    end

    it "limits the number of returned records" do
      model_class.create!(name: "A")
      model_class.create!(name: "B")
      model_class.create!(name: "C")

      expect(model_class.first_two.count).to eq(2)
    end
  end

  describe "custom scopes" do
    let(:model_class) do
      build_model(
        "name" => "contact",
        "fields" => [
          { "name" => "name", "type" => "string" }
        ],
        "scopes" => [
          { "name" => "custom_scope", "type" => "custom" }
        ],
        "options" => { "timestamps" => false }
      )
    end

    it "does not define the scope (left for Ruby code)" do
      expect(model_class).not_to respond_to(:custom_scope)
    end
  end

  describe "combined scopes" do
    let(:model_class) do
      build_model(
        "name" => "contact",
        "fields" => [
          { "name" => "name", "type" => "string" },
          { "name" => "status", "type" => "string" },
          { "name" => "priority", "type" => "integer" }
        ],
        "scopes" => [
          {
            "name" => "top_active",
            "where" => { "status" => "active" },
            "order" => { "priority" => "desc" },
            "limit" => 2
          }
        ],
        "options" => { "timestamps" => false }
      )
    end

    it "combines where, order, and limit" do
      model_class.create!(name: "A", status: "active", priority: 1)
      model_class.create!(name: "B", status: "inactive", priority: 10)
      model_class.create!(name: "C", status: "active", priority: 5)
      model_class.create!(name: "D", status: "active", priority: 10)

      results = model_class.top_active
      expect(results.map(&:name)).to eq([ "D", "C" ])
    end
  end

  describe "YAML null → Ruby nil → SQL IS NULL" do
    it "parses YAML null as Ruby nil in where conditions" do
      yaml_content = <<~YAML
        name: contact
        fields:
          - name: name
            type: string
          - name: phone
            type: string
        scopes:
          - name: without_phone
            where:
              phone: null
        options:
          timestamps: false
      YAML

      model_hash = YAML.safe_load(yaml_content)
      model_class = build_model(model_hash)

      model_class.create!(name: "Alice", phone: nil)
      model_class.create!(name: "Bob", phone: "555-1234")

      results = model_class.without_phone
      expect(results.map(&:name)).to eq([ "Alice" ])
    end

    it "parses YAML null in arrays for where conditions" do
      yaml_content = <<~YAML
        name: contact
        fields:
          - name: name
            type: string
          - name: phone
            type: string
        scopes:
          - name: blank_phone
            where:
              phone: [null, ""]
        options:
          timestamps: false
      YAML

      model_hash = YAML.safe_load(yaml_content)
      model_class = build_model(model_hash)

      model_class.create!(name: "Alice", phone: nil)
      model_class.create!(name: "Bob", phone: "")
      model_class.create!(name: "Carol", phone: "555-1234")

      results = model_class.blank_phone
      expect(results.map(&:name)).to contain_exactly("Alice", "Bob")
    end

    it "parses YAML null in where_not conditions" do
      yaml_content = <<~YAML
        name: contact
        fields:
          - name: name
            type: string
          - name: phone
            type: string
        scopes:
          - name: with_phone
            where_not:
              phone: null
        options:
          timestamps: false
      YAML

      model_hash = YAML.safe_load(yaml_content)
      model_class = build_model(model_hash)

      model_class.create!(name: "Alice", phone: nil)
      model_class.create!(name: "Bob", phone: "555-1234")

      results = model_class.with_phone
      expect(results.map(&:name)).to eq([ "Bob" ])
    end
  end
end
