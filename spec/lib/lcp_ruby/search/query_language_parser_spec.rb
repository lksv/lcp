require "spec_helper"

RSpec.describe LcpRuby::Search::QueryLanguageParser do
  def parse(input, max_nesting_depth: 10)
    described_class.new(input, max_nesting_depth: max_nesting_depth).parse
  end

  # Helper to extract leaf conditions from a recursive tree
  def leaf_conditions(tree)
    children = tree["children"] || []
    children.select { |c| c.key?("field") }
  end

  # Helper to extract groups from a recursive tree
  def child_groups(tree)
    children = tree["children"] || []
    children.select { |c| c.key?("children") }
  end

  describe "simple conditions" do
    it "parses equals with string value" do
      result = parse("status = 'published'")
      expect(leaf_conditions(result)).to contain_exactly(
        a_hash_including("field" => "status", "operator" => "eq", "value" => "published")
      )
    end

    it "parses equals with numeric value" do
      result = parse("price = 100")
      expect(leaf_conditions(result)).to contain_exactly(
        a_hash_including("field" => "price", "operator" => "eq", "value" => "100")
      )
    end

    it "parses decimal numeric value" do
      result = parse("price = 99.99")
      expect(leaf_conditions(result)).to contain_exactly(
        a_hash_including("field" => "price", "operator" => "eq", "value" => "99.99")
      )
    end

    it "parses negative numeric value" do
      result = parse("balance = -50")
      expect(leaf_conditions(result)).to contain_exactly(
        a_hash_including("field" => "balance", "operator" => "eq", "value" => "-50")
      )
    end

    it "parses not equals" do
      result = parse("status != 'draft'")
      expect(leaf_conditions(result)).to contain_exactly(
        a_hash_including("field" => "status", "operator" => "not_eq", "value" => "draft")
      )
    end

    it "parses greater than" do
      result = parse("price > 100")
      expect(leaf_conditions(result)).to contain_exactly(
        a_hash_including("field" => "price", "operator" => "gt", "value" => "100")
      )
    end

    it "parses greater than or equal" do
      result = parse("price >= 100")
      expect(leaf_conditions(result)).to contain_exactly(
        a_hash_including("field" => "price", "operator" => "gteq", "value" => "100")
      )
    end

    it "parses less than" do
      result = parse("price < 50")
      expect(leaf_conditions(result)).to contain_exactly(
        a_hash_including("field" => "price", "operator" => "lt", "value" => "50")
      )
    end

    it "parses less than or equal" do
      result = parse("price <= 50")
      expect(leaf_conditions(result)).to contain_exactly(
        a_hash_including("field" => "price", "operator" => "lteq", "value" => "50")
      )
    end

    it "parses contains operator (~)" do
      result = parse("name ~ 'Acme'")
      expect(leaf_conditions(result)).to contain_exactly(
        a_hash_including("field" => "name", "operator" => "cont", "value" => "Acme")
      )
    end

    it "parses not contains operator (!~)" do
      result = parse("name !~ 'test'")
      expect(leaf_conditions(result)).to contain_exactly(
        a_hash_including("field" => "name", "operator" => "not_cont", "value" => "test")
      )
    end

    it "parses starts with operator (^)" do
      result = parse("name ^ 'Acme'")
      expect(leaf_conditions(result)).to contain_exactly(
        a_hash_including("field" => "name", "operator" => "start", "value" => "Acme")
      )
    end

    it "parses ends with operator ($)" do
      result = parse("name $ 'Corp'")
      expect(leaf_conditions(result)).to contain_exactly(
        a_hash_including("field" => "name", "operator" => "end", "value" => "Corp")
      )
    end

    it "parses not starts with operator (!^)" do
      result = parse("name !^ 'test'")
      expect(leaf_conditions(result)).to contain_exactly(
        a_hash_including("field" => "name", "operator" => "not_start", "value" => "test")
      )
    end

    it "parses not ends with operator (!$)" do
      result = parse("name !$ 'Corp'")
      expect(leaf_conditions(result)).to contain_exactly(
        a_hash_including("field" => "name", "operator" => "not_end", "value" => "Corp")
      )
    end
  end

  describe "association paths" do
    it "parses dot-path field names" do
      result = parse("company.name ~ 'Acme'")
      expect(leaf_conditions(result)).to contain_exactly(
        a_hash_including("field" => "company.name", "operator" => "cont", "value" => "Acme")
      )
    end

    it "parses multi-level dot paths" do
      result = parse("company.address.city = 'London'")
      expect(leaf_conditions(result)).to contain_exactly(
        a_hash_including("field" => "company.address.city", "operator" => "eq", "value" => "London")
      )
    end
  end

  describe "list values" do
    it "parses in operator with list" do
      result = parse("status in ['draft', 'review']")
      expect(leaf_conditions(result)).to contain_exactly(
        a_hash_including("field" => "status", "operator" => "in", "value" => ["draft", "review"])
      )
    end

    it "parses not in operator" do
      result = parse("status not in ['archived']")
      expect(leaf_conditions(result)).to contain_exactly(
        a_hash_including("field" => "status", "operator" => "not_in", "value" => ["archived"])
      )
    end

    it "parses mixed numeric and string values in list" do
      result = parse("id in [1, 2, 3]")
      expect(leaf_conditions(result)).to contain_exactly(
        a_hash_including("field" => "id", "operator" => "in", "value" => ["1", "2", "3"])
      )
    end
  end

  describe "is operators" do
    it "parses is null" do
      result = parse("description is null")
      conditions = leaf_conditions(result)
      expect(conditions).to contain_exactly(
        a_hash_including("field" => "description", "operator" => "null")
      )
      expect(conditions.first).not_to have_key("value")
    end

    it "parses is not null" do
      result = parse("description is not null")
      expect(leaf_conditions(result)).to contain_exactly(
        a_hash_including("field" => "description", "operator" => "not_null")
      )
    end

    it "parses is present" do
      result = parse("name is present")
      expect(leaf_conditions(result)).to contain_exactly(
        a_hash_including("field" => "name", "operator" => "present")
      )
    end

    it "parses is blank" do
      result = parse("name is blank")
      expect(leaf_conditions(result)).to contain_exactly(
        a_hash_including("field" => "name", "operator" => "blank")
      )
    end

    it "parses is true" do
      result = parse("active is true")
      expect(leaf_conditions(result)).to contain_exactly(
        a_hash_including("field" => "active", "operator" => "true")
      )
    end

    it "parses is false" do
      result = parse("active is false")
      expect(leaf_conditions(result)).to contain_exactly(
        a_hash_including("field" => "active", "operator" => "false")
      )
    end

    it "parses is not true" do
      result = parse("active is not true")
      expect(leaf_conditions(result)).to contain_exactly(
        a_hash_including("field" => "active", "operator" => "not_true")
      )
    end

    it "parses is not false" do
      result = parse("active is not false")
      expect(leaf_conditions(result)).to contain_exactly(
        a_hash_including("field" => "active", "operator" => "not_false")
      )
    end

    it "parses is this_week" do
      result = parse("created_at is this_week")
      expect(leaf_conditions(result)).to contain_exactly(
        a_hash_including("field" => "created_at", "operator" => "this_week")
      )
    end

    it "parses is this_month" do
      result = parse("created_at is this_month")
      expect(leaf_conditions(result)).to contain_exactly(
        a_hash_including("field" => "created_at", "operator" => "this_month")
      )
    end

    it "parses is this_quarter" do
      result = parse("created_at is this_quarter")
      expect(leaf_conditions(result)).to contain_exactly(
        a_hash_including("field" => "created_at", "operator" => "this_quarter")
      )
    end

    it "parses is this_year" do
      result = parse("created_at is this_year")
      expect(leaf_conditions(result)).to contain_exactly(
        a_hash_including("field" => "created_at", "operator" => "this_year")
      )
    end
  end

  describe "AND combinations" do
    it "parses two AND conditions" do
      result = parse("status = 'published' and price >= 100")
      expect(result["combinator"]).to eq("and")
      expect(result["children"].size).to eq(2)
      expect(result["children"][0]["field"]).to eq("status")
      expect(result["children"][1]["field"]).to eq("price")
    end

    it "parses three AND conditions" do
      result = parse("a = 1 and b = 2 and c = 3")
      expect(result["children"].size).to eq(3)
    end
  end

  describe "OR combinations" do
    it "parses two OR conditions" do
      result = parse("status = 'draft' or status = 'review'")
      expect(result["combinator"]).to eq("or")
      expect(result["children"].size).to eq(2)
      expect(result["children"][0]["field"]).to eq("status")
      expect(result["children"][1]["field"]).to eq("status")
    end
  end

  describe "parentheses grouping" do
    it "parses parenthesized OR within AND" do
      result = parse("price > 100 and (status = 'draft' or status = 'review')")
      expect(result["combinator"]).to eq("and")
      expect(result["children"].size).to eq(2)
      expect(result["children"][0]["field"]).to eq("price")

      or_group = result["children"][1]
      expect(or_group["combinator"]).to eq("or")
      expect(or_group["children"].size).to eq(2)
    end

    it "parses nested parentheses" do
      result = parse("(a = 1 or b = 2)")
      expect(result["combinator"]).to eq("or")
      expect(result["children"].size).to eq(2)
    end
  end

  describe "scope references" do
    it "parses scope reference" do
      result = parse("@open_deals")
      expect(leaf_conditions(result)).to contain_exactly(
        a_hash_including("field" => "@open_deals", "operator" => "scope")
      )
    end

    it "combines scope with regular conditions" do
      result = parse("@active and price > 100")
      expect(result["children"].size).to eq(2)
      expect(result["children"][0]["operator"]).to eq("scope")
      expect(result["children"][1]["field"]).to eq("price")
    end
  end

  describe "relative dates" do
    it "parses {today}" do
      result = parse("created_at = {today}")
      expect(leaf_conditions(result)).to contain_exactly(
        a_hash_including("field" => "created_at", "operator" => "eq", "value" => "{today}")
      )
    end

    it "parses {7.days.ago}" do
      result = parse("created_at >= {7.days.ago}")
      expect(leaf_conditions(result)).to contain_exactly(
        a_hash_including("field" => "created_at", "operator" => "gteq", "value" => "{7.days.ago}")
      )
    end

    it "parses in {this_month}" do
      result = parse("created_at in {this_month}")
      expect(leaf_conditions(result)).to contain_exactly(
        a_hash_including("field" => "created_at", "operator" => "in", "value" => "{this_month}")
      )
    end
  end

  describe "string escaping" do
    it "handles escaped single quote" do
      result = parse("name = 'O\\'Brien'")
      expect(result["children"].first["value"]).to eq("O'Brien")
    end

    it "handles escaped backslash" do
      result = parse("path = 'C:\\\\Users'")
      expect(result["children"].first["value"]).to eq("C:\\Users")
    end
  end

  describe "edge cases" do
    it "returns empty tree for empty input" do
      result = parse("")
      expect(result["children"]).to eq([])
    end

    it "returns empty tree for whitespace-only input" do
      result = parse("   ")
      expect(result["children"]).to eq([])
    end
  end

  describe "recursive nesting" do
    it "preserves (A AND B) OR (C AND D) as OR(AND(a,b), AND(c,d))" do
      result = parse("(a = 1 and b = 2) or (c = 3 and d = 4)")
      expect(result["combinator"]).to eq("or")
      expect(result["children"].size).to eq(2)

      and_group_1 = result["children"][0]
      expect(and_group_1["combinator"]).to eq("and")
      expect(and_group_1["children"].map { |c| c["field"] }).to eq(%w[a b])

      and_group_2 = result["children"][1]
      expect(and_group_2["combinator"]).to eq("and")
      expect(and_group_2["children"].map { |c| c["field"] }).to eq(%w[c d])
    end

    it "preserves a OR (b AND c) as OR(a, AND(b,c))" do
      result = parse("a = 1 or (b = 2 and c = 3)")
      expect(result["combinator"]).to eq("or")
      expect(result["children"].size).to eq(2)
      expect(result["children"][0]["field"]).to eq("a")

      and_group = result["children"][1]
      expect(and_group["combinator"]).to eq("and")
      expect(and_group["children"].size).to eq(2)
    end

    it "preserves 3-level nesting" do
      result = parse("(a = 1 or (b = 2 and c = 3)) and d = 4")
      expect(result["combinator"]).to eq("and")
      expect(result["children"].size).to eq(2)

      or_group = result["children"][0]
      expect(or_group["combinator"]).to eq("or")
      expect(or_group["children"].size).to eq(2)
      expect(or_group["children"][0]["field"]).to eq("a")

      inner_and = or_group["children"][1]
      expect(inner_and["combinator"]).to eq("and")
      expect(inner_and["children"].map { |c| c["field"] }).to eq(%w[b c])

      expect(result["children"][1]["field"]).to eq("d")
    end

    it "flattens same-combinator parent/child: a AND (b AND c) → AND(a,b,c)" do
      result = parse("a = 1 and (b = 2 and c = 3)")
      expect(result["combinator"]).to eq("and")
      expect(result["children"].size).to eq(3)
      expect(result["children"].map { |c| c["field"] }).to eq(%w[a b c])
    end

    it "flattens same-combinator: a OR (b OR c) → OR(a,b,c)" do
      result = parse("a = 1 or (b = 2 or c = 3)")
      expect(result["combinator"]).to eq("or")
      expect(result["children"].size).to eq(3)
      expect(result["children"].map { |c| c["field"] }).to eq(%w[a b c])
    end

    it "raises ParseError when max_nesting_depth exceeded" do
      expect {
        parse("(a = 1 or (b = 2 and c = 3))", max_nesting_depth: 1)
      }.to raise_error(
        LcpRuby::Search::QueryLanguageParser::ParseError, /Nesting depth exceeds maximum of 1/
      )
    end

    it "allows expressions within max_nesting_depth: 2" do
      result = parse("a = 1 and (b = 2 or c = 3)", max_nesting_depth: 2)
      expect(result["combinator"]).to eq("and")
      expect(result["children"].size).to eq(2)
    end
  end

  describe "parse errors" do
    it "raises ParseError with position for unknown operator" do
      expect { parse("name UNKNOWN 'value'") }.to raise_error(
        LcpRuby::Search::QueryLanguageParser::ParseError
      ) { |e| expect(e.position).to be_a(Integer) }
    end

    it "raises ParseError for unterminated string" do
      expect { parse("name = 'unterminated") }.to raise_error(
        LcpRuby::Search::QueryLanguageParser::ParseError, /Unterminated/
      )
    end

    it "raises ParseError for unexpected end of input" do
      expect { parse("name =") }.to raise_error(
        LcpRuby::Search::QueryLanguageParser::ParseError
      )
    end

    it "raises ParseError for missing closing parenthesis" do
      expect { parse("(a = 1") }.to raise_error(
        LcpRuby::Search::QueryLanguageParser::ParseError, /Expected '\)'/
      )
    end

    it "raises ParseError for invalid is value" do
      expect { parse("name is something") }.to raise_error(
        LcpRuby::Search::QueryLanguageParser::ParseError, /Expected.*after 'is'/
      )
    end

    it "raises ParseError for input exceeding maximum length" do
      long_input = "a" * (described_class::MAX_INPUT_LENGTH + 1)
      expect { parse(long_input) }.to raise_error(
        LcpRuby::Search::QueryLanguageParser::ParseError, /Query too long/
      )
    end

    it "accepts input at the maximum length" do
      # Build a valid query that is exactly at the limit
      input = "name = '#{"a" * (described_class::MAX_INPUT_LENGTH - 10)}'"
      # Should not raise a length error (may raise a different parse error if malformed)
      expect { parse(input) }.not_to raise_error
    end
  end
end
