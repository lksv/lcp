module LcpRuby
  module Search
    class QueryLanguageParser
      class ParseError < StandardError
        attr_reader :position

        def initialize(message, position:)
          @position = position
          super(message)
        end
      end

      SYMBOL_OPERATORS = {
        "!=" => :not_eq,
        ">=" => :gteq,
        "<=" => :lteq,
        ">" => :gt,
        "<" => :lt,
        "=" => :eq,
        "~" => :cont,
        "!~" => :not_cont,
        "^" => :start,
        "$" => :end
      }.freeze

      # Sorted by length desc so multi-char operators match first
      SORTED_SYMBOL_OPS = SYMBOL_OPERATORS.keys.sort_by { |k| -k.length }.freeze

      KEYWORD_OPERATORS = {
        "in" => :in,
        "not in" => :not_in
      }.freeze

      IS_VALUES = {
        "null" => :null,
        "not null" => :not_null,
        "present" => :present,
        "blank" => :blank,
        "true" => :true,
        "false" => :false
      }.freeze

      # Sorted by length desc so "not null" matches before "not"
      SORTED_IS_VALUES = IS_VALUES.keys.sort_by { |k| -k.length }.freeze

      def initialize(input)
        @input = input.to_s
        @pos = 0
      end

      # Parse the input and return a condition tree.
      # Returns: { "combinator" => "and", "conditions" => [...], "groups" => [...] }
      def parse
        skip_whitespace
        return empty_tree if eof?

        tree = parse_or_expression
        skip_whitespace

        unless eof?
          error("Unexpected input at position #{@pos}")
        end

        normalize_tree(tree)
      end

      private

      def empty_tree
        { "combinator" => "and", "conditions" => [], "groups" => [] }
      end

      # or_expression = and_expression ("or" and_expression)*
      def parse_or_expression
        left = parse_and_expression
        parts = [ left ]

        while match_keyword("or")
          parts << parse_and_expression
        end

        if parts.size == 1
          parts.first
        else
          { "combinator" => "or", "parts" => parts }
        end
      end

      # and_expression = primary ("and" primary)*
      def parse_and_expression
        left = parse_primary
        parts = [ left ]

        while match_keyword("and")
          parts << parse_primary
        end

        if parts.size == 1
          parts.first
        else
          { "combinator" => "and", "parts" => parts }
        end
      end

      # primary = "(" expression ")" | scope_ref | condition
      def parse_primary
        skip_whitespace
        error("Unexpected end of input") if eof?

        if peek_char == "("
          advance # consume "("
          skip_whitespace
          expr = parse_or_expression
          skip_whitespace
          expect_char(")")
          expr
        elsif peek_char == "@"
          parse_scope_ref
        else
          parse_condition
        end
      end

      # scope_ref = "@" identifier
      def parse_scope_ref
        start_pos = @pos
        advance # consume "@"
        name = parse_identifier
        error("Expected scope name after '@'", pos: start_pos) if name.empty?
        { "field" => "@#{name}", "operator" => "scope" }
      end

      # condition = field_path operator value?
      def parse_condition
        field = parse_field_path
        skip_whitespace
        error("Expected operator after field '#{field}'") if eof?

        operator, value = parse_operator_and_value
        condition = { "field" => field, "operator" => operator.to_s }
        condition["value"] = value unless value.nil?
        condition
      end

      # field_path = identifier ("." identifier)*
      def parse_field_path
        skip_whitespace
        parts = [ parse_identifier ]
        error("Expected field name") if parts.first.empty?

        while peek_char == "."
          advance # consume "."
          part = parse_identifier
          error("Expected field name after '.'") if part.empty?
          parts << part
        end

        parts.join(".")
      end

      def parse_identifier
        start = @pos
        while !eof? && identifier_char?(peek_char)
          advance
        end
        @input[start...@pos]
      end

      def identifier_char?(ch)
        ch =~ /[a-zA-Z0-9_]/
      end

      def parse_operator_and_value
        skip_whitespace

        # "is" keyword (null/not null/present/blank/true/false)
        if match_keyword("is")
          skip_whitespace
          SORTED_IS_VALUES.each do |kw|
            if match_keyword(kw)
              return [ IS_VALUES[kw], nil ]
            end
          end
          error("Expected 'null', 'not null', 'present', 'blank', 'true', or 'false' after 'is'")
        end

        # "not in" keyword
        if match_keyword("not in")
          skip_whitespace
          values = parse_list_value
          return [ :not_in, values ]
        end

        # "in" keyword
        if match_keyword("in")
          skip_whitespace
          # Check for relative date marker
          if peek_char == "{"
            val = parse_relative_date
            return [ :in, val ]
          end
          values = parse_list_value
          return [ :in, values ]
        end

        # Symbol operators
        SORTED_SYMBOL_OPS.each do |sym|
          if @input[@pos, sym.length] == sym
            @pos += sym.length
            skip_whitespace
            value = parse_value
            return [ SYMBOL_OPERATORS[sym], value ]
          end
        end

        error("Unknown operator at position #{@pos}")
      end

      def parse_value
        skip_whitespace
        error("Expected value") if eof?

        case peek_char
        when "'"
          parse_string_literal
        when "{"
          parse_relative_date
        when "["
          parse_list_value
        else
          parse_number_or_unquoted
        end
      end

      def parse_string_literal
        advance # consume opening quote
        start = @pos
        result = +""

        until eof?
          ch = peek_char
          if ch == "\\"
            advance
            error("Unexpected end of input in string escape") if eof?
            result << peek_char
            advance
          elsif ch == "'"
            advance # consume closing quote
            return result
          else
            result << ch
            advance
          end
        end

        error("Unterminated string literal", pos: start - 1)
      end

      def parse_relative_date
        advance # consume "{"
        start = @pos
        until eof? || peek_char == "}"
          advance
        end
        error("Unterminated relative date expression", pos: start - 1) if eof?
        content = @input[start...@pos].strip
        advance # consume "}"
        "{#{content}}"
      end

      def parse_list_value
        expect_char("[")
        values = []
        skip_whitespace

        unless peek_char == "]"
          values << parse_value
          skip_whitespace
          while peek_char == ","
            advance # consume ","
            skip_whitespace
            values << parse_value
            skip_whitespace
          end
        end

        expect_char("]")
        values
      end

      def parse_number_or_unquoted
        start = @pos
        # Try to read a number (integer or decimal, possibly negative)
        if peek_char == "-" || peek_char =~ /[0-9]/
          advance if peek_char == "-"
          while !eof? && peek_char =~ /[0-9]/
            advance
          end
          if !eof? && peek_char == "."
            advance
            while !eof? && peek_char =~ /[0-9]/
              advance
            end
          end
          token = @input[start...@pos]
          return token if token =~ /\A-?\d+(\.\d+)?\z/

          # Not a valid number, backtrack
          @pos = start
        end

        # Unquoted word (identifier-like)
        while !eof? && peek_char =~ /[^\s()]/
          advance
        end

        token = @input[start...@pos]
        error("Expected value") if token.empty?
        token
      end

      def match_keyword(keyword)
        skip_whitespace
        len = keyword.length

        # Check that the keyword matches and is followed by non-identifier char or EOF
        if @input[@pos, len]&.downcase == keyword.downcase
          after = @pos + len
          if after >= @input.length || !identifier_char?(@input[after])
            @pos = after
            return true
          end
        end

        false
      end

      def skip_whitespace
        advance while !eof? && @input[@pos] =~ /\s/
      end

      def peek_char
        @input[@pos]
      end

      def advance
        @pos += 1
      end

      def eof?
        @pos >= @input.length
      end

      def expect_char(ch)
        skip_whitespace
        if eof? || peek_char != ch
          error("Expected '#{ch}'")
        end
        advance
      end

      def error(message, pos: nil)
        raise ParseError.new(message, position: pos || @pos)
      end

      # Convert a parse tree (with nested combinator groups) into the
      # flat condition tree format used by FilterParamBuilder.
      def normalize_tree(node)
        if node.is_a?(Hash) && node.key?("field")
          # Leaf condition
          { "combinator" => "and", "conditions" => [ node ], "groups" => [] }
        elsif node.is_a?(Hash) && node.key?("combinator") && node.key?("parts")
          flatten_combinator(node)
        elsif node.is_a?(Hash) && node.key?("combinator")
          node
        else
          empty_tree
        end
      end

      def flatten_combinator(node)
        combinator = node["combinator"]
        parts = node["parts"]

        if combinator == "and"
          # Top-level AND: conditions go to top-level, OR sub-groups become groups
          conditions = []
          groups = []

          parts.each do |part|
            normalized = normalize_tree(part)
            if part.is_a?(Hash) && part.key?("field")
              conditions << part
            elsif part.is_a?(Hash) && part["combinator"] == "or"
              # OR group becomes a sub-group
              or_conditions = extract_conditions(part)
              groups << { "combinator" => "or", "conditions" => or_conditions }
            elsif part.is_a?(Hash) && part["combinator"] == "and"
              # Nested AND: flatten into top-level
              inner = normalize_tree(part)
              conditions.concat(inner["conditions"])
              groups.concat(inner["groups"])
            else
              conditions.concat(normalized["conditions"])
              groups.concat(normalized["groups"])
            end
          end

          { "combinator" => "and", "conditions" => conditions, "groups" => groups }
        else
          # OR combinator
          or_conditions = extract_conditions(node)
          if or_conditions.all? { |c| c.is_a?(Hash) && c.key?("field") }
            # Simple OR of conditions: wrap in a group
            { "combinator" => "and", "conditions" => [], "groups" => [ { "combinator" => "or", "conditions" => or_conditions } ] }
          else
            { "combinator" => "and", "conditions" => [], "groups" => [ { "combinator" => "or", "conditions" => or_conditions } ] }
          end
        end
      end

      def extract_conditions(node)
        return [ node ] if node.is_a?(Hash) && node.key?("field")

        if node.is_a?(Hash) && node.key?("parts")
          node["parts"].flat_map { |p| extract_conditions(p) }
        elsif node.is_a?(Hash) && node.key?("conditions")
          node["conditions"]
        else
          []
        end
      end
    end
  end
end
