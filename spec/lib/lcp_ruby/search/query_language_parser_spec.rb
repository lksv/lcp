require "spec_helper"

RSpec.describe LcpRuby::Search::QueryLanguageParser do
  def parse(input)
    described_class.new(input).parse
  end

  describe "simple conditions" do
    it "parses equals with string value" do
      result = parse("status = 'published'")
      expect(result["conditions"]).to contain_exactly(
        a_hash_including("field" => "status", "operator" => "eq", "value" => "published")
      )
    end

    it "parses equals with numeric value" do
      result = parse("price = 100")
      expect(result["conditions"]).to contain_exactly(
        a_hash_including("field" => "price", "operator" => "eq", "value" => "100")
      )
    end

    it "parses decimal numeric value" do
      result = parse("price = 99.99")
      expect(result["conditions"]).to contain_exactly(
        a_hash_including("field" => "price", "operator" => "eq", "value" => "99.99")
      )
    end

    it "parses negative numeric value" do
      result = parse("balance = -50")
      expect(result["conditions"]).to contain_exactly(
        a_hash_including("field" => "balance", "operator" => "eq", "value" => "-50")
      )
    end

    it "parses not equals" do
      result = parse("status != 'draft'")
      expect(result["conditions"]).to contain_exactly(
        a_hash_including("field" => "status", "operator" => "not_eq", "value" => "draft")
      )
    end

    it "parses greater than" do
      result = parse("price > 100")
      expect(result["conditions"]).to contain_exactly(
        a_hash_including("field" => "price", "operator" => "gt", "value" => "100")
      )
    end

    it "parses greater than or equal" do
      result = parse("price >= 100")
      expect(result["conditions"]).to contain_exactly(
        a_hash_including("field" => "price", "operator" => "gteq", "value" => "100")
      )
    end

    it "parses less than" do
      result = parse("price < 50")
      expect(result["conditions"]).to contain_exactly(
        a_hash_including("field" => "price", "operator" => "lt", "value" => "50")
      )
    end

    it "parses less than or equal" do
      result = parse("price <= 50")
      expect(result["conditions"]).to contain_exactly(
        a_hash_including("field" => "price", "operator" => "lteq", "value" => "50")
      )
    end

    it "parses contains operator (~)" do
      result = parse("name ~ 'Acme'")
      expect(result["conditions"]).to contain_exactly(
        a_hash_including("field" => "name", "operator" => "cont", "value" => "Acme")
      )
    end

    it "parses not contains operator (!~)" do
      result = parse("name !~ 'test'")
      expect(result["conditions"]).to contain_exactly(
        a_hash_including("field" => "name", "operator" => "not_cont", "value" => "test")
      )
    end

    it "parses starts with operator (^)" do
      result = parse("name ^ 'Acme'")
      expect(result["conditions"]).to contain_exactly(
        a_hash_including("field" => "name", "operator" => "start", "value" => "Acme")
      )
    end

    it "parses ends with operator ($)" do
      result = parse("name $ 'Corp'")
      expect(result["conditions"]).to contain_exactly(
        a_hash_including("field" => "name", "operator" => "end", "value" => "Corp")
      )
    end
  end

  describe "association paths" do
    it "parses dot-path field names" do
      result = parse("company.name ~ 'Acme'")
      expect(result["conditions"]).to contain_exactly(
        a_hash_including("field" => "company.name", "operator" => "cont", "value" => "Acme")
      )
    end

    it "parses multi-level dot paths" do
      result = parse("company.address.city = 'London'")
      expect(result["conditions"]).to contain_exactly(
        a_hash_including("field" => "company.address.city", "operator" => "eq", "value" => "London")
      )
    end
  end

  describe "list values" do
    it "parses in operator with list" do
      result = parse("status in ['draft', 'review']")
      expect(result["conditions"]).to contain_exactly(
        a_hash_including("field" => "status", "operator" => "in", "value" => ["draft", "review"])
      )
    end

    it "parses not in operator" do
      result = parse("status not in ['archived']")
      expect(result["conditions"]).to contain_exactly(
        a_hash_including("field" => "status", "operator" => "not_in", "value" => ["archived"])
      )
    end

    it "parses mixed numeric and string values in list" do
      result = parse("id in [1, 2, 3]")
      expect(result["conditions"]).to contain_exactly(
        a_hash_including("field" => "id", "operator" => "in", "value" => ["1", "2", "3"])
      )
    end
  end

  describe "is operators" do
    it "parses is null" do
      result = parse("description is null")
      expect(result["conditions"]).to contain_exactly(
        a_hash_including("field" => "description", "operator" => "null")
      )
      expect(result["conditions"].first).not_to have_key("value")
    end

    it "parses is not null" do
      result = parse("description is not null")
      expect(result["conditions"]).to contain_exactly(
        a_hash_including("field" => "description", "operator" => "not_null")
      )
    end

    it "parses is present" do
      result = parse("name is present")
      expect(result["conditions"]).to contain_exactly(
        a_hash_including("field" => "name", "operator" => "present")
      )
    end

    it "parses is blank" do
      result = parse("name is blank")
      expect(result["conditions"]).to contain_exactly(
        a_hash_including("field" => "name", "operator" => "blank")
      )
    end

    it "parses is true" do
      result = parse("active is true")
      expect(result["conditions"]).to contain_exactly(
        a_hash_including("field" => "active", "operator" => "true")
      )
    end

    it "parses is false" do
      result = parse("active is false")
      expect(result["conditions"]).to contain_exactly(
        a_hash_including("field" => "active", "operator" => "false")
      )
    end
  end

  describe "AND combinations" do
    it "parses two AND conditions" do
      result = parse("status = 'published' and price >= 100")
      expect(result["combinator"]).to eq("and")
      expect(result["conditions"].size).to eq(2)
      expect(result["conditions"][0]["field"]).to eq("status")
      expect(result["conditions"][1]["field"]).to eq("price")
    end

    it "parses three AND conditions" do
      result = parse("a = 1 and b = 2 and c = 3")
      expect(result["conditions"].size).to eq(3)
    end
  end

  describe "OR combinations" do
    it "parses two OR conditions into a group" do
      result = parse("status = 'draft' or status = 'review'")
      expect(result["groups"].size).to eq(1)
      group = result["groups"].first
      expect(group["combinator"]).to eq("or")
      expect(group["conditions"].size).to eq(2)
    end
  end

  describe "parentheses grouping" do
    it "parses parenthesized OR within AND" do
      result = parse("price > 100 and (status = 'draft' or status = 'review')")
      expect(result["conditions"].size).to eq(1)
      expect(result["conditions"].first["field"]).to eq("price")
      expect(result["groups"].size).to eq(1)
      expect(result["groups"].first["conditions"].size).to eq(2)
    end

    it "parses nested parentheses" do
      result = parse("(a = 1 or b = 2)")
      expect(result["groups"].size).to eq(1)
      expect(result["groups"].first["conditions"].size).to eq(2)
    end
  end

  describe "scope references" do
    it "parses scope reference" do
      result = parse("@open_deals")
      expect(result["conditions"]).to contain_exactly(
        a_hash_including("field" => "@open_deals", "operator" => "scope")
      )
    end

    it "combines scope with regular conditions" do
      result = parse("@active and price > 100")
      expect(result["conditions"].size).to eq(2)
      expect(result["conditions"][0]["operator"]).to eq("scope")
      expect(result["conditions"][1]["field"]).to eq("price")
    end
  end

  describe "relative dates" do
    it "parses {today}" do
      result = parse("created_at = {today}")
      expect(result["conditions"]).to contain_exactly(
        a_hash_including("field" => "created_at", "operator" => "eq", "value" => "{today}")
      )
    end

    it "parses {7.days.ago}" do
      result = parse("created_at >= {7.days.ago}")
      expect(result["conditions"]).to contain_exactly(
        a_hash_including("field" => "created_at", "operator" => "gteq", "value" => "{7.days.ago}")
      )
    end

    it "parses in {this_month}" do
      result = parse("created_at in {this_month}")
      expect(result["conditions"]).to contain_exactly(
        a_hash_including("field" => "created_at", "operator" => "in", "value" => "{this_month}")
      )
    end
  end

  describe "string escaping" do
    it "handles escaped single quote" do
      result = parse("name = 'O\\'Brien'")
      expect(result["conditions"].first["value"]).to eq("O'Brien")
    end

    it "handles escaped backslash" do
      result = parse("path = 'C:\\\\Users'")
      expect(result["conditions"].first["value"]).to eq("C:\\Users")
    end
  end

  describe "edge cases" do
    it "returns empty tree for empty input" do
      result = parse("")
      expect(result["conditions"]).to eq([])
      expect(result["groups"]).to eq([])
    end

    it "returns empty tree for whitespace-only input" do
      result = parse("   ")
      expect(result["conditions"]).to eq([])
      expect(result["groups"]).to eq([])
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
