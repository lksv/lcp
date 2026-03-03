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
        "!^" => :not_start,
        "!$" => :not_end,
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
        "not null" => :not_null,
        "not true" => :not_true,
        "not false" => :not_false,
        "null" => :null,
        "present" => :present,
        "blank" => :blank,
        "true" => :true,
        "false" => :false,
        "this_week" => :this_week,
        "this_month" => :this_month,
        "this_quarter" => :this_quarter,
        "this_year" => :this_year
      }.freeze

      # Sorted by length desc so "not null" matches before "not"
      SORTED_IS_VALUES = IS_VALUES.keys.sort_by { |k| -k.length }.freeze

      WHITESPACE_RE = /\s/
      IDENTIFIER_CHAR_RE = /[a-zA-Z0-9_]/
      DIGIT_RE = /[0-9]/

      MAX_INPUT_LENGTH = 2000

      MAX_PARSE_DEPTH = 50

      def initialize(input, max_nesting_depth: 10)
        @input = input.to_s
        if @input.length > MAX_INPUT_LENGTH
          raise ParseError.new(
            "Query too long (#{@input.length} characters, maximum is #{MAX_INPUT_LENGTH})",
            position: 0
          )
        end
        @pos = 0
        @parse_depth = 0
        @max_nesting_depth = max_nesting_depth
      end

      # Parse the input and return a recursive condition tree.
      # Returns: { "combinator" => "and", "children" => [...] }
      # Each child is either a leaf condition { "field", "operator", "value" }
      # or a group { "combinator", "children" => [...] }
      def parse
        skip_whitespace
        return empty_tree if eof?

        tree = parse_or_expression
        skip_whitespace

        unless eof?
          error("Unexpected input at position #{@pos}")
        end

        result = normalize_ast(tree, depth: 1)

        # Ensure root is always a group node, not a bare leaf
        if result.is_a?(Hash) && result.key?("field")
          { "combinator" => "and", "children" => [ result ] }
        else
          result
        end
      end

      private

      def empty_tree
        { "combinator" => "and", "children" => [] }
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
          @parse_depth += 1
          if @parse_depth > MAX_PARSE_DEPTH
            error("Parentheses nested too deeply (maximum #{MAX_PARSE_DEPTH} levels)")
          end
          advance # consume "("
          skip_whitespace
          expr = parse_or_expression
          skip_whitespace
          expect_char(")")
          @parse_depth -= 1
          expr
        elsif peek_char == "@"
          parse_scope_ref
        else
          parse_condition
        end
      end

      # scope_ref = "@" identifier ("(" scope_params ")")?
      def parse_scope_ref
        start_pos = @pos
        advance # consume "@"
        name = parse_identifier
        error("Expected scope name after '@'", pos: start_pos) if name.empty?

        result = { "field" => "@#{name}", "operator" => "scope" }

        # Check for parameters: @name(key: value, ...)
        skip_whitespace
        if !eof? && peek_char == "("
          result["params"] = parse_scope_params
        end

        result
      end

      # Parse scope parameters: (key: value, key: value)
      def parse_scope_params
        advance # consume "("
        params = {}
        skip_whitespace

        unless peek_char == ")"
          key, value = parse_scope_param
          params[key] = value
          skip_whitespace

          while peek_char == ","
            advance # consume ","
            skip_whitespace
            key, value = parse_scope_param
            params[key] = value
            skip_whitespace
          end
        end

        expect_char(")")
        params
      end

      # Parse a single key: value pair
      def parse_scope_param
        skip_whitespace
        key = parse_identifier
        error("Expected parameter name") if key.empty?
        skip_whitespace
        expect_char(":")
        skip_whitespace
        value = parse_scope_param_value
        [ key, value ]
      end

      # Parse a scope parameter value (string, number, boolean)
      def parse_scope_param_value
        skip_whitespace
        error("Expected parameter value") if eof?

        case peek_char
        when "'", '"'
          parse_quoted_scope_value
        else
          # Try number or boolean/identifier
          start = @pos
          token = +""

          while !eof? && peek_char =~ /[^\s,)]/
            token << peek_char
            advance
          end

          error("Expected parameter value") if token.empty?

          case token.downcase
          when "true" then true
          when "false" then false
          else
            # Try numeric
            if token =~ /\A-?\d+\z/
              token.to_i
            elsif token =~ /\A-?\d+\.\d+\z/
              token.to_f
            else
              token
            end
          end
        end
      end

      def parse_quoted_scope_value
        quote_char = peek_char
        advance # consume opening quote
        result = +""

        until eof?
          ch = peek_char
          if ch == "\\"
            advance
            error("Unexpected end of input in string escape") if eof?
            result << peek_char
            advance
          elsif ch == quote_char
            advance # consume closing quote
            return result
          else
            result << ch
            advance
          end
        end

        error("Unterminated string in scope parameter")
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
        ch.match?(IDENTIFIER_CHAR_RE)
      end

      def parse_operator_and_value
        skip_whitespace

        # "is" keyword (null/not null/present/blank/true/false/not true/not false/this_week/...)
        if match_keyword("is")
          skip_whitespace
          SORTED_IS_VALUES.each do |kw|
            if match_keyword(kw)
              return [ IS_VALUES[kw], nil ]
            end
          end
          error("Expected one of: #{IS_VALUES.keys.join(', ')} after 'is'")
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
        if peek_char == "-" || peek_char&.match?(DIGIT_RE)
          advance if peek_char == "-"
          while !eof? && peek_char&.match?(DIGIT_RE)
            advance
          end
          if !eof? && peek_char == "."
            advance
            while !eof? && peek_char&.match?(DIGIT_RE)
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
        advance while !eof? && @input[@pos].match?(WHITESPACE_RE)
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

      # Convert the parsed AST (with "parts" arrays) into a recursive
      # condition tree with "children" arrays.
      #
      # Simplifications applied:
      # - Single-child groups are unwrapped
      # - Same-combinator parent/child are merged (AND(AND(a,b),c) → AND(a,b,c))
      # - Raises ParseError when depth exceeds max_nesting_depth
      def normalize_ast(node, depth:)
        if node.is_a?(Hash) && node.key?("field")
          # Leaf condition — return as-is
          node
        elsif node.is_a?(Hash) && node.key?("combinator") && node.key?("parts")
          combinator = node["combinator"]
          children = node["parts"].map { |part| normalize_ast(part, depth: depth + 1) }

          # Flatten same-combinator children into this node
          children = children.flat_map do |child|
            if child.is_a?(Hash) && child.key?("children") && child["combinator"] == combinator
              child["children"]
            else
              [ child ]
            end
          end

          # Single-child group: unwrap
          return children.first if children.size == 1

          if depth > @max_nesting_depth
            error("Nesting depth exceeds maximum of #{@max_nesting_depth}", pos: 0)
          end

          { "combinator" => combinator, "children" => children }
        elsif node.is_a?(Hash) && node.key?("combinator") && node.key?("children")
          node
        else
          empty_tree
        end
      end
    end
  end
end
