require "spec_helper"

RSpec.describe LcpRuby::Search::QueryLanguageSerializer do
  def serialize(tree)
    described_class.serialize(tree)
  end

  describe "simple conditions" do
    it "serializes equals with string" do
      tree = { "combinator" => "and", "children" => [{ "field" => "status", "operator" => "eq", "value" => "published" }] }
      expect(serialize(tree)).to eq("status = 'published'")
    end

    it "serializes equals with numeric value" do
      tree = { "combinator" => "and", "children" => [{ "field" => "price", "operator" => "eq", "value" => "100" }] }
      expect(serialize(tree)).to eq("price = 100")
    end

    it "serializes not equals" do
      tree = { "combinator" => "and", "children" => [{ "field" => "status", "operator" => "not_eq", "value" => "draft" }] }
      expect(serialize(tree)).to eq("status != 'draft'")
    end

    it "serializes greater than" do
      tree = { "combinator" => "and", "children" => [{ "field" => "price", "operator" => "gt", "value" => "100" }] }
      expect(serialize(tree)).to eq("price > 100")
    end

    it "serializes greater than or equal" do
      tree = { "combinator" => "and", "children" => [{ "field" => "price", "operator" => "gteq", "value" => "100" }] }
      expect(serialize(tree)).to eq("price >= 100")
    end

    it "serializes less than" do
      tree = { "combinator" => "and", "children" => [{ "field" => "price", "operator" => "lt", "value" => "50" }] }
      expect(serialize(tree)).to eq("price < 50")
    end

    it "serializes less than or equal" do
      tree = { "combinator" => "and", "children" => [{ "field" => "price", "operator" => "lteq", "value" => "50" }] }
      expect(serialize(tree)).to eq("price <= 50")
    end

    it "serializes contains" do
      tree = { "combinator" => "and", "children" => [{ "field" => "name", "operator" => "cont", "value" => "Acme" }] }
      expect(serialize(tree)).to eq("name ~ 'Acme'")
    end

    it "serializes not contains" do
      tree = { "combinator" => "and", "children" => [{ "field" => "name", "operator" => "not_cont", "value" => "test" }] }
      expect(serialize(tree)).to eq("name !~ 'test'")
    end

    it "serializes starts with" do
      tree = { "combinator" => "and", "children" => [{ "field" => "name", "operator" => "start", "value" => "Acme" }] }
      expect(serialize(tree)).to eq("name ^ 'Acme'")
    end

    it "serializes ends with" do
      tree = { "combinator" => "and", "children" => [{ "field" => "name", "operator" => "end", "value" => "Corp" }] }
      expect(serialize(tree)).to eq("name $ 'Corp'")
    end

    it "serializes not starts with" do
      tree = { "combinator" => "and", "children" => [{ "field" => "name", "operator" => "not_start", "value" => "test" }] }
      expect(serialize(tree)).to eq("name !^ 'test'")
    end

    it "serializes not ends with" do
      tree = { "combinator" => "and", "children" => [{ "field" => "name", "operator" => "not_end", "value" => "Corp" }] }
      expect(serialize(tree)).to eq("name !$ 'Corp'")
    end
  end

  describe "no-value operators" do
    it "serializes is null" do
      tree = { "combinator" => "and", "children" => [{ "field" => "notes", "operator" => "null" }] }
      expect(serialize(tree)).to eq("notes is null")
    end

    it "serializes is not null" do
      tree = { "combinator" => "and", "children" => [{ "field" => "notes", "operator" => "not_null" }] }
      expect(serialize(tree)).to eq("notes is not null")
    end

    it "serializes is present" do
      tree = { "combinator" => "and", "children" => [{ "field" => "name", "operator" => "present" }] }
      expect(serialize(tree)).to eq("name is present")
    end

    it "serializes is blank" do
      tree = { "combinator" => "and", "children" => [{ "field" => "name", "operator" => "blank" }] }
      expect(serialize(tree)).to eq("name is blank")
    end

    it "serializes is true" do
      tree = { "combinator" => "and", "children" => [{ "field" => "active", "operator" => "true" }] }
      expect(serialize(tree)).to eq("active is true")
    end

    it "serializes is false" do
      tree = { "combinator" => "and", "children" => [{ "field" => "active", "operator" => "false" }] }
      expect(serialize(tree)).to eq("active is false")
    end

    it "serializes is not true" do
      tree = { "combinator" => "and", "children" => [{ "field" => "active", "operator" => "not_true" }] }
      expect(serialize(tree)).to eq("active is not true")
    end

    it "serializes is not false" do
      tree = { "combinator" => "and", "children" => [{ "field" => "active", "operator" => "not_false" }] }
      expect(serialize(tree)).to eq("active is not false")
    end

    it "serializes is this_week" do
      tree = { "combinator" => "and", "children" => [{ "field" => "created_at", "operator" => "this_week" }] }
      expect(serialize(tree)).to eq("created_at is this_week")
    end

    it "serializes is this_month" do
      tree = { "combinator" => "and", "children" => [{ "field" => "created_at", "operator" => "this_month" }] }
      expect(serialize(tree)).to eq("created_at is this_month")
    end

    it "serializes is this_quarter" do
      tree = { "combinator" => "and", "children" => [{ "field" => "created_at", "operator" => "this_quarter" }] }
      expect(serialize(tree)).to eq("created_at is this_quarter")
    end

    it "serializes is this_year" do
      tree = { "combinator" => "and", "children" => [{ "field" => "created_at", "operator" => "this_year" }] }
      expect(serialize(tree)).to eq("created_at is this_year")
    end
  end

  describe "list values" do
    it "serializes in with list" do
      tree = { "combinator" => "and", "children" => [{ "field" => "status", "operator" => "in", "value" => ["draft", "review"] }] }
      expect(serialize(tree)).to eq("status in ['draft', 'review']")
    end

    it "serializes not in with list" do
      tree = { "combinator" => "and", "children" => [{ "field" => "status", "operator" => "not_in", "value" => ["archived"] }] }
      expect(serialize(tree)).to eq("status not in ['archived']")
    end

    it "serializes numeric values in list unquoted" do
      tree = { "combinator" => "and", "children" => [{ "field" => "id", "operator" => "in", "value" => ["1", "2"] }] }
      expect(serialize(tree)).to eq("id in [1, 2]")
    end
  end

  describe "recursive groups" do
    it "serializes OR group" do
      tree = {
        "combinator" => "or",
        "children" => [
          { "field" => "status", "operator" => "eq", "value" => "draft" },
          { "field" => "status", "operator" => "eq", "value" => "review" }
        ]
      }
      expect(serialize(tree)).to eq("status = 'draft' or status = 'review'")
    end

    it "serializes AND condition with nested OR group" do
      tree = {
        "combinator" => "and",
        "children" => [
          { "field" => "price", "operator" => "gt", "value" => "100" },
          {
            "combinator" => "or",
            "children" => [
              { "field" => "status", "operator" => "eq", "value" => "a" },
              { "field" => "status", "operator" => "eq", "value" => "b" }
            ]
          }
        ]
      }
      expect(serialize(tree)).to eq("price > 100 and (status = 'a' or status = 'b')")
    end

    it "serializes nested AND within OR with parentheses" do
      tree = {
        "combinator" => "or",
        "children" => [
          {
            "combinator" => "and",
            "children" => [
              { "field" => "a", "operator" => "eq", "value" => "1" },
              { "field" => "b", "operator" => "eq", "value" => "2" }
            ]
          },
          { "field" => "c", "operator" => "eq", "value" => "3" }
        ]
      }
      expect(serialize(tree)).to eq("(a = 1 and b = 2) or c = 3")
    end

    it "serializes (A AND B) OR (C AND D)" do
      tree = {
        "combinator" => "or",
        "children" => [
          {
            "combinator" => "and",
            "children" => [
              { "field" => "a", "operator" => "eq", "value" => "1" },
              { "field" => "b", "operator" => "eq", "value" => "2" }
            ]
          },
          {
            "combinator" => "and",
            "children" => [
              { "field" => "c", "operator" => "eq", "value" => "3" },
              { "field" => "d", "operator" => "eq", "value" => "4" }
            ]
          }
        ]
      }
      expect(serialize(tree)).to eq("(a = 1 and b = 2) or (c = 3 and d = 4)")
    end
  end

  describe "scope references" do
    it "serializes scope references" do
      tree = { "combinator" => "and", "children" => [{ "field" => "@open_deals", "operator" => "scope" }] }
      expect(serialize(tree)).to eq("@open_deals")
    end
  end

  describe "relative dates" do
    it "preserves relative date markers" do
      tree = { "combinator" => "and", "children" => [{ "field" => "created_at", "operator" => "gteq", "value" => "{7.days.ago}" }] }
      expect(serialize(tree)).to eq("created_at >= {7.days.ago}")
    end

    it "serializes in with relative date" do
      tree = { "combinator" => "and", "children" => [{ "field" => "created_at", "operator" => "in", "value" => "{this_month}" }] }
      expect(serialize(tree)).to eq("created_at in {this_month}")
    end
  end

  describe "edge cases" do
    it "returns empty string for nil input" do
      expect(serialize(nil)).to eq("")
    end

    it "returns empty string for empty tree" do
      expect(serialize({ "combinator" => "and", "children" => [] })).to eq("")
    end

    it "handles string with single quote" do
      tree = { "combinator" => "and", "children" => [{ "field" => "name", "operator" => "eq", "value" => "O'Brien" }] }
      expect(serialize(tree)).to eq("name = 'O\\'Brien'")
    end
  end

  describe "legacy format support" do
    it "serializes legacy {conditions, groups} format" do
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

  describe "round-trip: parse(serialize(tree))" do
    let(:parser) { LcpRuby::Search::QueryLanguageParser }

    it "round-trips simple eq condition" do
      tree = { "combinator" => "and", "children" => [{ "field" => "name", "operator" => "eq", "value" => "test" }] }
      ql = serialize(tree)
      parsed = parser.new(ql).parse
      expect(parsed["children"].first["field"]).to eq("name")
      expect(parsed["children"].first["operator"]).to eq("eq")
      expect(parsed["children"].first["value"]).to eq("test")
    end

    it "round-trips multiple AND conditions" do
      tree = {
        "combinator" => "and",
        "children" => [
          { "field" => "a", "operator" => "eq", "value" => "1" },
          { "field" => "b", "operator" => "gt", "value" => "10" }
        ]
      }
      ql = serialize(tree)
      parsed = parser.new(ql).parse
      expect(parsed["children"].size).to eq(2)
    end

    it "round-trips is null operator" do
      tree = { "combinator" => "and", "children" => [{ "field" => "notes", "operator" => "null" }] }
      ql = serialize(tree)
      parsed = parser.new(ql).parse
      expect(parsed["children"].first["operator"]).to eq("null")
    end

    it "round-trips not_start operator (!^)" do
      tree = { "combinator" => "and", "children" => [{ "field" => "name", "operator" => "not_start", "value" => "test" }] }
      ql = serialize(tree)
      expect(ql).to eq("name !^ 'test'")
      parsed = parser.new(ql).parse
      expect(parsed["children"].first["operator"]).to eq("not_start")
      expect(parsed["children"].first["value"]).to eq("test")
    end

    it "round-trips not_end operator (!$)" do
      tree = { "combinator" => "and", "children" => [{ "field" => "name", "operator" => "not_end", "value" => "Corp" }] }
      ql = serialize(tree)
      expect(ql).to eq("name !$ 'Corp'")
      parsed = parser.new(ql).parse
      expect(parsed["children"].first["operator"]).to eq("not_end")
      expect(parsed["children"].first["value"]).to eq("Corp")
    end

    it "round-trips is not true" do
      tree = { "combinator" => "and", "children" => [{ "field" => "active", "operator" => "not_true" }] }
      ql = serialize(tree)
      expect(ql).to eq("active is not true")
      parsed = parser.new(ql).parse
      expect(parsed["children"].first["operator"]).to eq("not_true")
    end

    it "round-trips is not false" do
      tree = { "combinator" => "and", "children" => [{ "field" => "active", "operator" => "not_false" }] }
      ql = serialize(tree)
      expect(ql).to eq("active is not false")
      parsed = parser.new(ql).parse
      expect(parsed["children"].first["operator"]).to eq("not_false")
    end

    it "round-trips is this_week" do
      tree = { "combinator" => "and", "children" => [{ "field" => "created_at", "operator" => "this_week" }] }
      ql = serialize(tree)
      expect(ql).to eq("created_at is this_week")
      parsed = parser.new(ql).parse
      expect(parsed["children"].first["operator"]).to eq("this_week")
    end

    it "round-trips is this_month" do
      tree = { "combinator" => "and", "children" => [{ "field" => "created_at", "operator" => "this_month" }] }
      ql = serialize(tree)
      parsed = parser.new(ql).parse
      expect(parsed["children"].first["operator"]).to eq("this_month")
    end

    it "round-trips OR group" do
      tree = {
        "combinator" => "or",
        "children" => [
          { "field" => "a", "operator" => "eq", "value" => "x" },
          { "field" => "b", "operator" => "eq", "value" => "y" }
        ]
      }
      ql = serialize(tree)
      parsed = parser.new(ql).parse
      expect(parsed["combinator"]).to eq("or")
      expect(parsed["children"].size).to eq(2)
    end

    it "round-trips nested AND within OR" do
      tree = {
        "combinator" => "or",
        "children" => [
          {
            "combinator" => "and",
            "children" => [
              { "field" => "a", "operator" => "eq", "value" => "1" },
              { "field" => "b", "operator" => "eq", "value" => "2" }
            ]
          },
          {
            "combinator" => "and",
            "children" => [
              { "field" => "c", "operator" => "eq", "value" => "3" },
              { "field" => "d", "operator" => "eq", "value" => "4" }
            ]
          }
        ]
      }
      ql = serialize(tree)
      parsed = parser.new(ql).parse
      expect(parsed["combinator"]).to eq("or")
      expect(parsed["children"].size).to eq(2)
      expect(parsed["children"][0]["combinator"]).to eq("and")
      expect(parsed["children"][1]["combinator"]).to eq("and")
    end
  end
end
