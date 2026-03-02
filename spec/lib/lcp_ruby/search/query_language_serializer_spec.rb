require "spec_helper"

RSpec.describe LcpRuby::Search::QueryLanguageSerializer do
  def serialize(tree)
    described_class.serialize(tree)
  end

  describe "simple conditions" do
    it "serializes equals with string" do
      tree = { "conditions" => [{ "field" => "status", "operator" => "eq", "value" => "published" }], "groups" => [] }
      expect(serialize(tree)).to eq("status = 'published'")
    end

    it "serializes equals with numeric value" do
      tree = { "conditions" => [{ "field" => "price", "operator" => "eq", "value" => "100" }], "groups" => [] }
      expect(serialize(tree)).to eq("price = 100")
    end

    it "serializes not equals" do
      tree = { "conditions" => [{ "field" => "status", "operator" => "not_eq", "value" => "draft" }], "groups" => [] }
      expect(serialize(tree)).to eq("status != 'draft'")
    end

    it "serializes greater than" do
      tree = { "conditions" => [{ "field" => "price", "operator" => "gt", "value" => "100" }], "groups" => [] }
      expect(serialize(tree)).to eq("price > 100")
    end

    it "serializes greater than or equal" do
      tree = { "conditions" => [{ "field" => "price", "operator" => "gteq", "value" => "100" }], "groups" => [] }
      expect(serialize(tree)).to eq("price >= 100")
    end

    it "serializes less than" do
      tree = { "conditions" => [{ "field" => "price", "operator" => "lt", "value" => "50" }], "groups" => [] }
      expect(serialize(tree)).to eq("price < 50")
    end

    it "serializes less than or equal" do
      tree = { "conditions" => [{ "field" => "price", "operator" => "lteq", "value" => "50" }], "groups" => [] }
      expect(serialize(tree)).to eq("price <= 50")
    end

    it "serializes contains" do
      tree = { "conditions" => [{ "field" => "name", "operator" => "cont", "value" => "Acme" }], "groups" => [] }
      expect(serialize(tree)).to eq("name ~ 'Acme'")
    end

    it "serializes not contains" do
      tree = { "conditions" => [{ "field" => "name", "operator" => "not_cont", "value" => "test" }], "groups" => [] }
      expect(serialize(tree)).to eq("name !~ 'test'")
    end

    it "serializes starts with" do
      tree = { "conditions" => [{ "field" => "name", "operator" => "start", "value" => "Acme" }], "groups" => [] }
      expect(serialize(tree)).to eq("name ^ 'Acme'")
    end

    it "serializes ends with" do
      tree = { "conditions" => [{ "field" => "name", "operator" => "end", "value" => "Corp" }], "groups" => [] }
      expect(serialize(tree)).to eq("name $ 'Corp'")
    end
  end

  describe "no-value operators" do
    it "serializes is null" do
      tree = { "conditions" => [{ "field" => "notes", "operator" => "null" }], "groups" => [] }
      expect(serialize(tree)).to eq("notes is null")
    end

    it "serializes is not null" do
      tree = { "conditions" => [{ "field" => "notes", "operator" => "not_null" }], "groups" => [] }
      expect(serialize(tree)).to eq("notes is not null")
    end

    it "serializes is present" do
      tree = { "conditions" => [{ "field" => "name", "operator" => "present" }], "groups" => [] }
      expect(serialize(tree)).to eq("name is present")
    end

    it "serializes is blank" do
      tree = { "conditions" => [{ "field" => "name", "operator" => "blank" }], "groups" => [] }
      expect(serialize(tree)).to eq("name is blank")
    end

    it "serializes is true" do
      tree = { "conditions" => [{ "field" => "active", "operator" => "true" }], "groups" => [] }
      expect(serialize(tree)).to eq("active is true")
    end

    it "serializes is false" do
      tree = { "conditions" => [{ "field" => "active", "operator" => "false" }], "groups" => [] }
      expect(serialize(tree)).to eq("active is false")
    end
  end

  describe "list values" do
    it "serializes in with list" do
      tree = { "conditions" => [{ "field" => "status", "operator" => "in", "value" => ["draft", "review"] }], "groups" => [] }
      expect(serialize(tree)).to eq("status in ['draft', 'review']")
    end

    it "serializes not in with list" do
      tree = { "conditions" => [{ "field" => "status", "operator" => "not_in", "value" => ["archived"] }], "groups" => [] }
      expect(serialize(tree)).to eq("status not in ['archived']")
    end

    it "serializes numeric values in list unquoted" do
      tree = { "conditions" => [{ "field" => "id", "operator" => "in", "value" => ["1", "2"] }], "groups" => [] }
      expect(serialize(tree)).to eq("id in [1, 2]")
    end
  end

  describe "groups" do
    it "serializes OR group in parentheses" do
      tree = {
        "conditions" => [],
        "groups" => [
          {
            "combinator" => "or",
            "conditions" => [
              { "field" => "status", "operator" => "eq", "value" => "draft" },
              { "field" => "status", "operator" => "eq", "value" => "review" }
            ]
          }
        ]
      }
      expect(serialize(tree)).to eq("(status = 'draft' or status = 'review')")
    end

    it "serializes conditions AND groups" do
      tree = {
        "conditions" => [
          { "field" => "price", "operator" => "gt", "value" => "100" }
        ],
        "groups" => [
          {
            "combinator" => "or",
            "conditions" => [
              { "field" => "status", "operator" => "eq", "value" => "a" },
              { "field" => "status", "operator" => "eq", "value" => "b" }
            ]
          }
        ]
      }
      expect(serialize(tree)).to eq("price > 100 and (status = 'a' or status = 'b')")
    end
  end

  describe "scope references" do
    it "serializes scope references" do
      tree = { "conditions" => [{ "field" => "@open_deals", "operator" => "scope" }], "groups" => [] }
      expect(serialize(tree)).to eq("@open_deals")
    end
  end

  describe "relative dates" do
    it "preserves relative date markers" do
      tree = { "conditions" => [{ "field" => "created_at", "operator" => "gteq", "value" => "{7.days.ago}" }], "groups" => [] }
      expect(serialize(tree)).to eq("created_at >= {7.days.ago}")
    end

    it "serializes in with relative date" do
      tree = { "conditions" => [{ "field" => "created_at", "operator" => "in", "value" => "{this_month}" }], "groups" => [] }
      expect(serialize(tree)).to eq("created_at in {this_month}")
    end
  end

  describe "edge cases" do
    it "returns empty string for nil input" do
      expect(serialize(nil)).to eq("")
    end

    it "returns empty string for empty tree" do
      expect(serialize({ "conditions" => [], "groups" => [] })).to eq("")
    end

    it "handles string with single quote" do
      tree = { "conditions" => [{ "field" => "name", "operator" => "eq", "value" => "O'Brien" }], "groups" => [] }
      expect(serialize(tree)).to eq("name = 'O\\'Brien'")
    end
  end

  describe "round-trip: parse(serialize(tree))" do
    let(:parser) { LcpRuby::Search::QueryLanguageParser }

    it "round-trips simple eq condition" do
      tree = { "conditions" => [{ "field" => "name", "operator" => "eq", "value" => "test" }], "groups" => [] }
      ql = serialize(tree)
      parsed = parser.new(ql).parse
      expect(parsed["conditions"].first["field"]).to eq("name")
      expect(parsed["conditions"].first["operator"]).to eq("eq")
      expect(parsed["conditions"].first["value"]).to eq("test")
    end

    it "round-trips multiple AND conditions" do
      tree = {
        "conditions" => [
          { "field" => "a", "operator" => "eq", "value" => "1" },
          { "field" => "b", "operator" => "gt", "value" => "10" }
        ],
        "groups" => []
      }
      ql = serialize(tree)
      parsed = parser.new(ql).parse
      expect(parsed["conditions"].size).to eq(2)
    end

    it "round-trips is null operator" do
      tree = { "conditions" => [{ "field" => "notes", "operator" => "null" }], "groups" => [] }
      ql = serialize(tree)
      parsed = parser.new(ql).parse
      expect(parsed["conditions"].first["operator"]).to eq("null")
    end

    it "round-trips OR group" do
      tree = {
        "conditions" => [],
        "groups" => [
          {
            "combinator" => "or",
            "conditions" => [
              { "field" => "a", "operator" => "eq", "value" => "x" },
              { "field" => "b", "operator" => "eq", "value" => "y" }
            ]
          }
        ]
      }
      ql = serialize(tree)
      parsed = parser.new(ql).parse
      expect(parsed["groups"].size).to eq(1)
      expect(parsed["groups"].first["conditions"].size).to eq(2)
    end
  end
end
