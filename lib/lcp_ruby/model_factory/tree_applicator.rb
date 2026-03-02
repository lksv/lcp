module LcpRuby
  module ModelFactory
    class TreeApplicator
      def initialize(model_class, model_definition)
        @model_class = model_class
        @model_definition = model_definition
      end

      def apply!
        return unless @model_definition.tree?

        store_tree_config
        apply_associations
        apply_scopes
        apply_instance_methods
        apply_cycle_detection
        ensure_parent_index
        configure_positioning
      end

      private

      def store_tree_config
        parent_field = @model_definition.tree_parent_field
        max_depth = @model_definition.tree_max_depth
        children_name = @model_definition.tree_children_name
        parent_name = @model_definition.tree_parent_name

        @model_class.define_singleton_method(:lcp_tree_parent_field) { parent_field }
        @model_class.define_singleton_method(:lcp_tree_max_depth) { max_depth }
        @model_class.define_singleton_method(:lcp_tree_children_name) { children_name }
        @model_class.define_singleton_method(:lcp_tree_parent_name) { parent_name }
      end

      def apply_associations
        parent_field = @model_definition.tree_parent_field
        children_name = @model_definition.tree_children_name.to_sym
        parent_name = @model_definition.tree_parent_name.to_sym
        model_name = @model_definition.name
        dependent = resolve_dependent

        @model_class.belongs_to parent_name,
          class_name: "LcpRuby::Dynamic::#{model_name.camelize}",
          foreign_key: parent_field,
          optional: true,
          inverse_of: children_name

        @model_class.has_many children_name,
          class_name: "LcpRuby::Dynamic::#{model_name.camelize}",
          foreign_key: parent_field,
          dependent: dependent,
          inverse_of: parent_name
      end

      def apply_scopes
        parent_field = @model_definition.tree_parent_field

        @model_class.scope :roots, -> { where(parent_field => nil) }
        @model_class.scope :leaves, -> {
          where.not(id: select(parent_field).where.not(parent_field => nil))
        }
      end

      def apply_instance_methods
        parent_field = @model_definition.tree_parent_field
        max_depth = @model_definition.tree_max_depth
        children_name = @model_definition.tree_children_name.to_sym
        parent_name = @model_definition.tree_parent_name.to_sym
        table = @model_definition.table_name

        @model_class.define_method(:root?) do
          self[parent_field].nil?
        end

        @model_class.define_method(:leaf?) do
          public_send(children_name).none?
        end

        # Ancestors: iterative walk up the parent chain (nearest-first).
        # Uses recursive CTE for efficiency.
        @model_class.define_method(:ancestors) do
          return self.class.none if root?

          cte_sql = <<~SQL.squish
            WITH RECURSIVE tree_ancestors AS (
              SELECT * FROM #{self.class.connection.quote_table_name(table)}
              WHERE id = #{self.class.connection.quote(self[parent_field])}
              UNION ALL
              SELECT t.* FROM #{self.class.connection.quote_table_name(table)} t
              INNER JOIN tree_ancestors ta ON t.id = ta.#{self.class.connection.quote_column_name(parent_field)}
            )
            SELECT id FROM tree_ancestors LIMIT #{max_depth}
          SQL

          ancestor_ids = self.class.connection.select_values(cte_sql)
          # Return in nearest-first order (parent, grandparent, ...)
          self.class.where(id: ancestor_ids).order(
            Arel.sql("CASE #{ancestor_ids.each_with_index.map { |aid, i| "WHEN id = #{self.class.connection.quote(aid)} THEN #{i}" }.join(' ')} END")
          )
        end

        # Descendants: recursive CTE to get all nodes below this one.
        @model_class.define_method(:descendants) do
          cte_sql = <<~SQL.squish
            WITH RECURSIVE tree_descendants AS (
              SELECT * FROM #{self.class.connection.quote_table_name(table)}
              WHERE #{self.class.connection.quote_column_name(parent_field)} = #{self.class.connection.quote(id)}
              UNION ALL
              SELECT t.* FROM #{self.class.connection.quote_table_name(table)} t
              INNER JOIN tree_descendants td ON t.#{self.class.connection.quote_column_name(parent_field)} = td.id
            )
            SELECT id FROM tree_descendants LIMIT #{max_depth * 1000}
          SQL

          descendant_ids = self.class.connection.select_values(cte_sql)
          self.class.where(id: descendant_ids)
        end

        @model_class.define_method(:subtree) do
          self.class.where(id: subtree_ids)
        end

        @model_class.define_method(:subtree_ids) do
          [id] + descendants.pluck(:id)
        end

        @model_class.define_method(:siblings) do
          self.class.where(parent_field => self[parent_field]).where.not(id: id)
        end

        @model_class.define_method(:depth) do
          return 0 if root?
          ancestors.count
        end

        # Path: root to self (inclusive), ordered root-first.
        @model_class.define_method(:path) do
          return self.class.where(id: id) if root?

          ancestor_list = ancestors.to_a
          ordered = ancestor_list.reverse + [self]
          self.class.where(id: ordered.map(&:id)).order(
            Arel.sql("CASE #{ordered.each_with_index.map { |r, i| "WHEN id = #{self.class.connection.quote(r.id)} THEN #{i}" }.join(' ')} END")
          )
        end

        @model_class.define_method(:root) do
          return self if root?
          path.first
        end
      end

      def apply_cycle_detection
        parent_field = @model_definition.tree_parent_field
        max_depth = @model_definition.tree_max_depth
        parent_name = @model_definition.tree_parent_name.to_sym

        @model_class.define_method(:lcp_tree_no_cycle) do
          return unless send(:"#{parent_field}_changed?") || (new_record? && self[parent_field].present?)

          pid = self[parent_field]
          return if pid.nil?

          # Self-reference check
          if pid == id
            errors.add(parent_field, "cannot reference itself")
            return
          end

          # Walk the ancestor chain to detect cycles and enforce max_depth
          visited = Set.new([id])
          current_id = pid
          depth_count = 1

          while current_id.present?
            if visited.include?(current_id)
              errors.add(parent_field, "would create a cycle in the tree")
              return
            end

            if depth_count > max_depth
              errors.add(parent_field, "would exceed maximum tree depth of #{max_depth}")
              return
            end

            visited << current_id
            current_id = self.class.where(id: current_id).pick(parent_field)
            depth_count += 1
          end
        end
        @model_class.send(:private, :lcp_tree_no_cycle)

        @model_class.validate :lcp_tree_no_cycle
      end

      def ensure_parent_index
        parent_field = @model_definition.tree_parent_field
        table = @model_definition.table_name
        conn = @model_class.connection

        return unless conn.table_exists?(table)

        index_name = "index_#{table}_on_#{parent_field}"
        unless conn.index_exists?(table, parent_field)
          conn.add_index(table, parent_field, name: index_name)
        end
      end

      def configure_positioning
        return unless @model_definition.tree_ordered?
        # Skip if model already has explicit positioning config
        return if @model_definition.positioned?

        parent_field = @model_definition.tree_parent_field
        position_field = @model_definition.tree_position_field

        # Set positioning config on the model definition so PositioningApplicator picks it up
        @model_definition.instance_variable_set(
          :@positioning_config,
          { "field" => position_field, "scope" => [parent_field] }
        )
      end

      def resolve_dependent
        dep = @model_definition.tree_dependent
        case dep
        when "discard"
          # SoftDeleteApplicator handles cascade discard; AR gets nil
          nil
        when "destroy", "nullify", "restrict_with_exception", "restrict_with_error"
          dep.to_sym
        else
          :destroy
        end
      end
    end
  end
end
