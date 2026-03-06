module LcpRuby
  module TreeHelper
    def render_tree_rows(roots, children_map, columns, depth:, default_expanded:, match_ids:,
                         reparentable: false, search_active: false)
      return "".html_safe if roots.blank?

      roots.each_with_index.map { |record, idx|
        render_tree_row(record, children_map, columns, depth: depth,
          default_expanded: default_expanded, match_ids: match_ids,
          reparentable: reparentable, search_active: search_active,
          guides: [], is_last: idx == roots.size - 1)
      }.join.html_safe
    end

    private

    def render_tree_row(record, children_map, columns, depth:, default_expanded:, match_ids:,
                        reparentable: false, search_active: false, guides: [], is_last: true)
      children = children_map[record.id] || []
      has_children = children.any?
      expanded = tree_expanded?(depth, default_expanded, search_active)
      is_match = match_ids.nil? || match_ids.include?(record.id)
      context_class = (!is_match && match_ids) ? "lcp-tree-ancestor-context" : ""

      parent_field = current_model_definition.tree_parent_field

      item_classes = compute_item_classes(record, current_presenter)

      row = content_tag(:tr,
        class: [ "lcp-tree-row", context_class.presence, item_classes.presence ].compact.join(" "),
        data: {
          record_id: record.id,
          parent_id: record[parent_field],
          depth: depth,
          has_children: has_children,
          expanded: expanded,
          **(reparentable && !search_active ? {
            reparent_url: reparent_resource_path(record),
            subtree_ids: (@subtree_ids_map && @subtree_ids_map[record.id]) || record.id.to_s
          } : {})
        }.compact
      ) do
        cells = ActiveSupport::SafeBuffer.new

        # Drag handle column
        if reparentable && !search_active
          cells << content_tag(:td, content_tag(:span, "&#9776;".html_safe, class: "lcp-drag-handle"),
                               class: "lcp-drag-column")
        end

        columns.each_with_index do |col, idx|
          cell_content = ActiveSupport::SafeBuffer.new

          # First column gets tree guide lines and toggle
          if idx == 0
            # Guide lines for ancestor levels (vertical pipes or blanks)
            if depth > 0
              guides.each do |has_line|
                cell_content << content_tag(:span, "", class: "lcp-tree-guide#{' lcp-tree-guide-pipe' if has_line}")
              end

              # Connector at current depth (tee or elbow)
              connector_class = is_last ? "lcp-tree-guide lcp-tree-guide-elbow" : "lcp-tree-guide lcp-tree-guide-tee"
              cell_content << content_tag(:span, "", class: connector_class)
            end

            if has_children
              chevron_class = expanded ? "lcp-tree-chevron expanded" : "lcp-tree-chevron"
              cell_content << content_tag(:button, "&#9654;".html_safe,
                type: "button", class: chevron_class,
                data: { lcp_tree_toggle: record.id })
            else
              cell_content << content_tag(:span, "", class: "lcp-tree-leaf-spacer")
            end
          end

          value = @field_resolver.resolve(record, col["field"], fk_map: @fk_map)

          if col["link_to"] == "show"
            cell_content << link_to(render_display_value(value, col["renderer"], col["options"], nil, record: record), resource_path(record))
          elsif col["partial"]
            cell_content << render(partial: col["partial"], locals: { value: value, record: record, options: col["options"] || {} })
          elsif col["renderer"]
            cell_content << render_display_value(value, col["renderer"], col["options"], nil, record: record)
          elsif value.is_a?(Array)
            cell_content << render_display_value(value, "collection", {})
          else
            cell_content << empty_value_placeholder(value, current_presenter)
          end

          # First column wraps content in flex node for stretching guide lines
          td_content = idx == 0 ? content_tag(:div, cell_content, class: "lcp-tree-node") : cell_content
          td_class = "#{hidden_on_classes(col)} #{'lcp-pinned-left' if col['pinned'] == 'left'}"
          td_class = "lcp-tree-cell #{td_class}" if idx == 0
          cells << content_tag(:td, td_content, class: td_class.strip)
        end

        # Actions column
        cells << content_tag(:td, class: "lcp-actions") do
          @action_set.single_actions(record).map { |action|
            render("lcp_ruby/resources/action_button", action: action, record: record, css_class: "")
          }.join.html_safe
        end

        cells
      end

      # Recursively render children
      child_guides = guides + [ !is_last ]
      child_rows = if has_children
        children.each_with_index.map { |child, idx|
          render_tree_row(child, children_map, columns, depth: depth + 1,
            default_expanded: default_expanded, match_ids: match_ids,
            reparentable: reparentable, search_active: search_active,
            guides: child_guides, is_last: idx == children.size - 1)
        }.join.html_safe
      else
        "".html_safe
      end

      row + child_rows
    end

    def tree_expanded?(depth, default_expanded, search_active)
      return true if search_active
      return true if default_expanded == "all"

      default_expanded.is_a?(Integer) && depth < default_expanded
    end
  end
end
