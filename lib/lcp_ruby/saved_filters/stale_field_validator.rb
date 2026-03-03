module LcpRuby
  module SavedFilters
    class StaleFieldValidator
      # Walks a condition tree and validates each leaf's field against available filter fields.
      # Removes invalid leaves and collects descriptions of skipped conditions.
      #
      # @param condition_tree [Hash] the condition tree to validate
      # @param filter_metadata [Hash] output from FilterMetadataBuilder#build
      # @return [Hash] { valid_tree: Hash, skipped_conditions: Array<String> }
      def self.validate(condition_tree, filter_metadata)
        new(condition_tree, filter_metadata).validate
      end

      def initialize(condition_tree, filter_metadata)
        @tree = condition_tree
        @valid_field_names = build_valid_field_set(filter_metadata)
        @skipped = []
      end

      def validate
        valid_tree = process_node(@tree)
        valid_tree ||= { "combinator" => "and", "children" => [] }

        { valid_tree: valid_tree, skipped_conditions: @skipped }
      end

      private

      def build_valid_field_set(metadata)
        fields = metadata[:fields] || []
        names = Set.new(fields.map { |f| f[:name].to_s })

        # Scope references (@scope_name) are always valid
        names
      end

      def process_node(node)
        return nil if node.blank?

        if node.key?("field")
          # Leaf condition
          validate_leaf(node)
        elsif node.key?("children")
          # Group node
          process_group(node)
        else
          node
        end
      end

      def validate_leaf(leaf)
        field = leaf["field"]
        operator = leaf["operator"]

        # Scope references are always valid
        return leaf if operator == "scope" && field&.start_with?("@")

        # Custom field references
        return leaf if field&.start_with?("cf[")

        # Check against valid field names
        unless @valid_field_names.include?(field.to_s)
          @skipped << "Field '#{field}' no longer exists or is not accessible"
          return nil
        end

        leaf
      end

      def process_group(group)
        combinator = group["combinator"] || "and"
        children = (group["children"] || []).filter_map { |child| process_node(child) }

        return nil if children.empty?

        if children.size == 1
          children.first
        else
          { "combinator" => combinator, "children" => children }
        end
      end
    end
  end
end
