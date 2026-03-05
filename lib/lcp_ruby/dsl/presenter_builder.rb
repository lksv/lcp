module LcpRuby
  module Dsl
    class PresenterBuilder
      def initialize(name)
        @name = name.to_s
        @model_name = nil
        @label_value = nil
        @slug_value = nil
        @icon_value = nil
        @index_hash = nil
        @show_hash = nil
        @form_hash = nil
        @search_hash = nil
        @actions = []
        @options = {}
      end

      # Top-level setters
      def model(value)
        @model_name = value.to_s
      end

      def label(value)
        @label_value = value.to_s
      end

      def slug(value)
        @slug_value = value.to_s
      end

      def icon(value)
        @icon_value = value.to_s
      end

      def read_only(value = true)
        @options["read_only"] = value
      end

      def embeddable(value = true)
        @options["embeddable"] = value
      end

      def redirect_after(create: nil, update: nil)
        ra = {}
        ra["create"] = create.to_s if create
        ra["update"] = update.to_s if update
        @options["redirect_after"] = ra
      end

      def empty_value(value)
        @options["empty_value"] = value
      end

      def scope(value)
        @options["scope"] = value.to_s
      end

      # View blocks
      def index(&block)
        builder = IndexBuilder.new
        builder.instance_eval(&block)
        @index_hash = builder.to_hash
      end

      def show(&block)
        builder = ShowBuilder.new
        builder.instance_eval(&block)
        @show_hash = builder.to_hash
      end

      def form(&block)
        builder = FormBuilder.new
        builder.instance_eval(&block)
        @form_hash = builder.to_hash
      end

      def search(enabled: nil, &block)
        if block
          builder = SearchBuilder.new
          builder.instance_eval(&block)
          @search_hash = builder.to_hash
        elsif !enabled.nil?
          @search_hash = { "enabled" => enabled }
        end
      end

      # Flat actions
      def action(name, type:, on:, **options)
        action_hash = {
          "name" => name.to_s,
          "type" => type.to_s
        }
        action_hash["label"] = options[:label] if options.key?(:label)
        action_hash["icon"] = options[:icon].to_s if options.key?(:icon)
        action_hash["confirm"] = options[:confirm] if options.key?(:confirm)
        action_hash["confirm_message"] = options[:confirm_message] if options.key?(:confirm_message)
        action_hash["style"] = options[:style].to_s if options.key?(:style)
        action_hash["visible_when"] = stringify_visible_when(options[:visible_when]) if options.key?(:visible_when)
        action_hash["disable_when"] = stringify_visible_when(options[:disable_when]) if options.key?(:disable_when)

        @actions << { on: on.to_s, hash: action_hash }
      end

      def to_hash
        hash = { "name" => @name }
        hash["model"] = @model_name if @model_name
        hash["label"] = @label_value if @label_value
        hash["slug"] = @slug_value if @slug_value
        hash["icon"] = @icon_value if @icon_value

        hash["index"] = @index_hash if @index_hash
        hash["show"] = @show_hash if @show_hash
        hash["form"] = @form_hash if @form_hash
        hash["search"] = @search_hash if @search_hash

        unless @actions.empty?
          hash["actions"] = build_actions_hash
        end

        # Options are stored at the top level for PresenterDefinition.from_hash
        @options.each { |k, v| hash[k] = v }

        hash
      end

      # Merge this builder's output on top of a parent hash.
      # Keys defined by the child replace the parent's values entirely (section-level replace).
      def to_hash_with_parent(parent_hash)
        child_hash = to_hash
        merged = Marshal.load(Marshal.dump(parent_hash))

        # Always override these from child if defined
        %w[name label slug icon read_only embeddable redirect_after empty_value scope].each do |key|
          merged[key] = child_hash[key] if child_hash.key?(key)
        end

        # Section-level replace: child replaces parent entirely for these keys
        %w[index show form search actions].each do |key|
          merged[key] = child_hash[key] if child_hash.key?(key)
        end

        # Model is always from parent unless child overrides
        merged["model"] = child_hash["model"] if child_hash.key?("model")

        merged
      end

      private

      def build_actions_hash
        grouped = {}
        @actions.each do |entry|
          key = entry[:on]
          grouped[key] ||= []
          grouped[key] << entry[:hash]
        end
        grouped
      end

      def stringify_visible_when(condition)
        return nil unless condition.is_a?(Hash)

        result = {}
        condition.each do |k, v|
          key = k.to_s
          result[key] = case v
          when Symbol then v.to_s
          when Array then v.map { |item| item.is_a?(Symbol) ? item.to_s : item }
          when Hash then stringify_visible_when(v)
          else v
          end
        end
        result
      end
    end

    class IndexBuilder
      def initialize
        @reorderable_value = nil
        @layout_value = nil
        @default_view = nil
        @default_sort = nil
        @per_page_value = nil
        @per_page_options_value = nil
        @views_available = nil
        @columns = []
        @row_click_value = nil
        @empty_message_value = nil
        @actions_position_value = nil
        @includes_list = nil
        @eager_load_list = nil
        @description_value = nil
        @tree_view_value = nil
        @default_expanded_value = nil
        @reparentable_value = nil
        @tile_hash = nil
        @sort_fields = []
        @summary_hash = nil
      end

      def reorderable(value = true)
        @reorderable_value = value
      end

      def description(text)
        @description_value = text
      end

      def default_view(value)
        @default_view = value.to_s
      end

      def default_sort(field, direction = :asc)
        @default_sort = { "field" => field.to_s, "direction" => direction.to_s }
      end

      def per_page(value)
        @per_page_value = value
      end

      def views_available(*values)
        @views_available = values.flatten.map(&:to_s)
      end

      def row_click(value)
        @row_click_value = value.to_s
      end

      def empty_message(value)
        @empty_message_value = value
      end

      def actions_position(value)
        @actions_position_value = value.to_s
      end

      def column(field_name, **options)
        col = { "field" => field_name.to_s }
        options.each do |k, v|
          col[k.to_s] = v.is_a?(Symbol) ? v.to_s : HashUtils.stringify_deep(v)
        end
        @columns << col
      end

      def includes(*assocs)
        @includes_list = assocs.flatten.map { |a| a.is_a?(Hash) ? HashUtils.stringify_deep(a) : a.to_s }
      end

      def eager_load(*assocs)
        @eager_load_list = assocs.flatten.map { |a| a.is_a?(Hash) ? HashUtils.stringify_deep(a) : a.to_s }
      end

      def tree_view(value = true)
        @tree_view_value = value
      end

      def default_expanded(value)
        @default_expanded_value = value
      end

      def reparentable(value = true)
        @reparentable_value = value
      end

      def layout(value)
        @layout_value = value.to_s
      end

      def tile(&block)
        builder = TileBuilder.new
        builder.instance_eval(&block)
        @tile_hash = builder.to_hash
      end

      def sort_field(field, label: nil)
        entry = { "field" => field.to_s }
        entry["label"] = label if label
        @sort_fields << entry
      end

      def per_page_options(*values)
        @per_page_options_value = values.flatten
      end

      def summary(&block)
        builder = SummaryBuilder.new
        builder.instance_eval(&block)
        @summary_hash = builder.to_hash
      end

      def to_hash
        hash = {}
        hash["layout"] = @layout_value if @layout_value
        hash["reorderable"] = @reorderable_value unless @reorderable_value.nil?
        hash["description"] = @description_value if @description_value
        hash["default_view"] = @default_view if @default_view
        hash["views_available"] = @views_available if @views_available
        hash["default_sort"] = @default_sort if @default_sort
        hash["per_page"] = @per_page_value if @per_page_value
        hash["per_page_options"] = @per_page_options_value if @per_page_options_value
        hash["table_columns"] = @columns unless @columns.empty?
        hash["tile"] = @tile_hash if @tile_hash
        hash["sort_fields"] = @sort_fields unless @sort_fields.empty?
        hash["summary"] = @summary_hash if @summary_hash
        hash["row_click"] = @row_click_value if @row_click_value
        hash["empty_message"] = @empty_message_value if @empty_message_value
        hash["actions_position"] = @actions_position_value if @actions_position_value
        hash["includes"] = @includes_list if @includes_list
        hash["eager_load"] = @eager_load_list if @eager_load_list
        hash["tree_view"] = @tree_view_value unless @tree_view_value.nil?
        hash["default_expanded"] = @default_expanded_value unless @default_expanded_value.nil?
        hash["reparentable"] = @reparentable_value unless @reparentable_value.nil?
        hash
      end
    end

    class TileBuilder
      def initialize
        @hash = {}
        @fields = []
      end

      def title_field(name)
        @hash["title_field"] = name.to_s
      end

      def subtitle_field(name, renderer: nil, options: nil)
        @hash["subtitle_field"] = name.to_s
        @hash["subtitle_renderer"] = renderer.to_s if renderer
        @hash["subtitle_options"] = HashUtils.stringify_deep(options) if options
      end

      def image_field(name)
        @hash["image_field"] = name.to_s
      end

      def description_field(name, max_lines: nil)
        @hash["description_field"] = name.to_s
        @hash["description_max_lines"] = max_lines if max_lines
      end

      def columns(value)
        @hash["columns"] = value
      end

      def card_link(value)
        @hash["card_link"] = value.to_s
      end

      def actions(value)
        @hash["actions"] = value.to_s
      end

      def field(name, **options)
        f = { "field" => name.to_s }
        options.each do |k, v|
          f[k.to_s] = v.is_a?(Symbol) ? v.to_s : HashUtils.stringify_deep(v)
        end
        @fields << f
      end

      def to_hash
        result = @hash.dup
        result["fields"] = @fields unless @fields.empty?
        result
      end
    end

    class SummaryBuilder
      def initialize
        @enabled_value = true
        @fields = []
      end

      def enabled(value = true)
        @enabled_value = value
      end

      def field(name, function:, **options)
        f = { "field" => name.to_s, "function" => function.to_s }
        f["label"] = options[:label] if options[:label]
        f["renderer"] = options[:renderer].to_s if options[:renderer]
        f["options"] = HashUtils.stringify_deep(options[:options]) if options[:options]
        @fields << f
      end

      def to_hash
        hash = { "enabled" => @enabled_value }
        hash["fields"] = @fields unless @fields.empty?
        hash
      end
    end

    class SectionBuilder
      def initialize
        @fields = []
      end

      def field(name, **options)
        field_hash = { "field" => name.to_s }
        options.each do |k, v|
          field_hash[k.to_s] = v.is_a?(Symbol) ? v.to_s : HashUtils.stringify_deep(v)
        end
        @fields << field_hash
      end

      def divider(label: nil)
        d = { "type" => "divider" }
        d["label"] = label if label
        @fields << d
      end

      def info(text)
        @fields << { "type" => "info", "text" => text }
      end

      def to_fields
        @fields
      end
    end

    # Builder for nested_fields blocks that supports both flat fields and sub-sections.
    # Using both `field` and `section` in the same block is not allowed.
    class NestedSectionBuilder
      def initialize
        @fields = []
        @sub_sections = []
      end

      def field(name, **options)
        if @sub_sections.any?
          raise ArgumentError, "Cannot mix field and section calls in nested_fields — use one or the other"
        end

        field_hash = { "field" => name.to_s }
        options.each do |k, v|
          field_hash[k.to_s] = v.is_a?(Symbol) ? v.to_s : HashUtils.stringify_deep(v)
        end
        @fields << field_hash
      end

      def section(title, columns: nil, collapsible: false, collapsed: false,
                  visible_when: nil, disable_when: nil, &block)
        if @fields.any?
          raise ArgumentError, "Cannot mix field and section calls in nested_fields — use one or the other"
        end

        ss = { "title" => title }
        ss["columns"] = columns if columns
        ss["collapsible"] = collapsible if collapsible
        ss["collapsed"] = collapsed if collapsed
        ss["visible_when"] = HashUtils.stringify_deep(visible_when) if visible_when
        ss["disable_when"] = HashUtils.stringify_deep(disable_when) if disable_when

        if block
          builder = SectionBuilder.new
          builder.instance_eval(&block)
          ss["fields"] = builder.to_fields
        end

        @sub_sections << ss
      end

      def has_sub_sections?
        @sub_sections.any?
      end

      def to_fields
        @fields
      end

      def to_sub_sections
        @sub_sections
      end
    end

    class ShowBuilder
      def initialize
        @layout = []
        @includes_list = nil
        @eager_load_list = nil
        @description_value = nil
        @copy_url_value = nil
      end

      def description(text)
        @description_value = text
      end

      def copy_url(value)
        @copy_url_value = value
      end

      def section(title, columns: 1, description: nil, responsive: nil,
                  visible_when: nil, disable_when: nil, &block)
        section_hash = { "section" => title, "columns" => columns }
        section_hash["description"] = description if description
        section_hash["responsive"] = stringify_deep(responsive) if responsive
        section_hash["visible_when"] = stringify_deep(visible_when) if visible_when
        section_hash["disable_when"] = stringify_deep(disable_when) if disable_when
        if block
          builder = SectionBuilder.new
          builder.instance_eval(&block)
          section_hash["fields"] = builder.to_fields
        end
        @layout << section_hash
      end

      def json_items_list(title, json_field:, target_model: nil, columns: nil,
                          empty_message: nil, visible_when: nil, disable_when: nil, &block)
        entry = {
          "section" => title,
          "type" => "json_items_list",
          "json_field" => json_field.to_s
        }
        entry["target_model"] = target_model.to_s if target_model
        entry["columns"] = columns if columns
        entry["empty_message"] = empty_message if empty_message
        entry["visible_when"] = stringify_deep(visible_when) if visible_when
        entry["disable_when"] = stringify_deep(disable_when) if disable_when
        if block
          builder = NestedSectionBuilder.new
          builder.instance_eval(&block)
          if builder.has_sub_sections?
            entry["sub_sections"] = builder.to_sub_sections
          else
            entry["fields"] = builder.to_fields
          end
        end
        @layout << entry
      end

      def association_list(title, association:, display_template: nil, link: nil, sort: nil,
                                limit: nil, empty_message: nil, scope: nil,
                                visible_when: nil, disable_when: nil)
        entry = {
          "section" => title,
          "type" => "association_list",
          "association" => association.to_s
        }
        entry["display_template"] = display_template.to_s if display_template
        entry["link"] = link unless link.nil?
        entry["sort"] = stringify_deep(sort) if sort
        entry["limit"] = limit if limit
        entry["empty_message"] = empty_message if empty_message
        entry["scope"] = scope.to_s if scope
        entry["visible_when"] = stringify_deep(visible_when) if visible_when
        entry["disable_when"] = stringify_deep(disable_when) if disable_when
        @layout << entry
      end

      def includes(*assocs)
        @includes_list = assocs.flatten.map { |a| a.is_a?(Hash) ? HashUtils.stringify_deep(a) : a.to_s }
      end

      def eager_load(*assocs)
        @eager_load_list = assocs.flatten.map { |a| a.is_a?(Hash) ? HashUtils.stringify_deep(a) : a.to_s }
      end

      def to_hash
        hash = {}
        hash["description"] = @description_value if @description_value
        hash["copy_url"] = @copy_url_value unless @copy_url_value.nil?
        hash["layout"] = @layout
        hash["includes"] = @includes_list if @includes_list
        hash["eager_load"] = @eager_load_list if @eager_load_list
        hash
      end

      private

      def stringify_deep(value)
        HashUtils.stringify_deep(value)
      end
    end

    class FormBuilder
      def initialize
        @sections = []
        @layout_value = nil
        @includes_list = nil
        @eager_load_list = nil
        @description_value = nil
      end

      def description(text)
        @description_value = text
      end

      def layout(value)
        @layout_value = value.to_s
      end

      def section(title, columns: 1, description: nil, responsive: nil, collapsible: false, collapsed: false,
                  visible_when: nil, disable_when: nil, &block)
        section_hash = { "title" => title, "columns" => columns }
        section_hash["description"] = description if description
        section_hash["responsive"] = stringify_deep(responsive) if responsive
        section_hash["collapsible"] = collapsible if collapsible
        section_hash["collapsed"] = collapsed if collapsed
        section_hash["visible_when"] = stringify_deep(visible_when) if visible_when
        section_hash["disable_when"] = stringify_deep(disable_when) if disable_when
        if block
          builder = SectionBuilder.new
          builder.instance_eval(&block)
          section_hash["fields"] = builder.to_fields
        end
        @sections << section_hash
      end

      def nested_fields(title, association: nil, json_field: nil, target_model: nil,
                        description: nil, allow_add: true, allow_remove: true,
                        min: nil, max: nil, add_label: nil, empty_message: nil,
                        sortable: false, columns: nil, visible_when: nil, disable_when: nil, &block)
        if association && json_field
          raise ArgumentError, "nested_fields cannot have both association: and json_field:"
        end
        unless association || json_field
          raise ArgumentError, "nested_fields requires either association: or json_field:"
        end

        section_hash = {
          "title" => title,
          "type" => "nested_fields",
          "allow_add" => allow_add,
          "allow_remove" => allow_remove
        }
        section_hash["association"] = association.to_s if association
        section_hash["json_field"] = json_field.to_s if json_field
        section_hash["target_model"] = target_model.to_s if target_model
        section_hash["description"] = description if description
        section_hash["columns"] = columns if columns
        section_hash["min"] = min if min
        section_hash["max"] = max if max
        section_hash["add_label"] = add_label if add_label
        section_hash["empty_message"] = empty_message if empty_message
        section_hash["sortable"] = sortable if sortable
        section_hash["visible_when"] = stringify_deep(visible_when) if visible_when
        section_hash["disable_when"] = stringify_deep(disable_when) if disable_when
        if block
          builder = NestedSectionBuilder.new
          builder.instance_eval(&block)
          if builder.has_sub_sections?
            section_hash["sub_sections"] = builder.to_sub_sections
          else
            section_hash["fields"] = builder.to_fields
          end
        end
        @sections << section_hash
      end

      def includes(*assocs)
        @includes_list = assocs.flatten.map { |a| a.is_a?(Hash) ? HashUtils.stringify_deep(a) : a.to_s }
      end

      def eager_load(*assocs)
        @eager_load_list = assocs.flatten.map { |a| a.is_a?(Hash) ? HashUtils.stringify_deep(a) : a.to_s }
      end

      def to_hash
        hash = {}
        hash["description"] = @description_value if @description_value
        hash["sections"] = @sections
        hash["layout"] = @layout_value if @layout_value
        hash["includes"] = @includes_list if @includes_list
        hash["eager_load"] = @eager_load_list if @eager_load_list
        hash
      end

      private

      def stringify_deep(value)
        HashUtils.stringify_deep(value)
      end
    end

    class SearchBuilder
      def initialize
        @enabled = true
        @searchable_fields_list = nil
        @placeholder_value = nil
        @filters = []
        @auto_search_value = nil
        @debounce_ms_value = nil
        @min_query_length_value = nil
        @advanced_filter_hash = nil
      end

      def enabled(value)
        @enabled = value
      end

      def searchable_fields(*fields)
        @searchable_fields_list = fields.flatten.map(&:to_s)
      end

      def placeholder(value)
        @placeholder_value = value
      end

      def auto_search(value = true)
        @auto_search_value = value
      end

      def debounce_ms(value)
        @debounce_ms_value = value
      end

      def min_query_length(value)
        @min_query_length_value = value
      end

      def filter(name, label:, default: false, scope: nil)
        filter_hash = { "name" => name.to_s, "label" => label }
        filter_hash["default"] = true if default
        filter_hash["scope"] = scope.to_s if scope
        @filters << filter_hash
      end

      def advanced_filter(&block)
        builder = AdvancedFilterBuilder.new
        builder.instance_eval(&block)
        @advanced_filter_hash = builder.to_hash
      end

      def to_hash
        hash = { "enabled" => @enabled }
        hash["searchable_fields"] = @searchable_fields_list if @searchable_fields_list
        hash["placeholder"] = @placeholder_value if @placeholder_value
        hash["auto_search"] = @auto_search_value unless @auto_search_value.nil?
        hash["debounce_ms"] = @debounce_ms_value if @debounce_ms_value
        hash["min_query_length"] = @min_query_length_value if @min_query_length_value
        hash["predefined_filters"] = @filters unless @filters.empty?
        hash["advanced_filter"] = @advanced_filter_hash if @advanced_filter_hash
        hash
      end
    end

    class AdvancedFilterBuilder
      def initialize
        @hash = { "enabled" => true }
      end

      def enabled(value)
        @hash["enabled"] = value
      end

      def max_conditions(value)
        @hash["max_conditions"] = value
      end

      def max_association_depth(value)
        @hash["max_association_depth"] = value
      end

      def default_combinator(value)
        @hash["default_combinator"] = value.to_s
      end

      def allow_or_groups(value)
        @hash["allow_or_groups"] = value
      end

      def query_language(value)
        @hash["query_language"] = value
      end

      def max_nesting_depth(value)
        @hash["max_nesting_depth"] = value
      end

      def filterable_fields(*fields)
        @hash["filterable_fields"] = fields.flatten.map(&:to_s)
      end

      def filterable_fields_except(*fields)
        @hash["filterable_fields_except"] = fields.flatten.map(&:to_s)
      end

      def field_options(name, operators: nil)
        @hash["field_options"] ||= {}
        opts = {}
        opts["operators"] = operators.map(&:to_s) if operators
        @hash["field_options"][name.to_s] = opts
      end

      def preset(name, label:, conditions:)
        @hash["presets"] ||= []
        @hash["presets"] << {
          "name" => name.to_s,
          "label" => label,
          "conditions" => conditions.map { |c| c.transform_keys(&:to_s) }
        }
      end

      def saved_filters(&block)
        builder = SavedFiltersBuilder.new
        builder.instance_eval(&block)
        @hash["saved_filters"] = builder.to_hash
      end

      def to_hash
        @hash
      end
    end

    class SavedFiltersBuilder
      def initialize
        @hash = {}
      end

      def enabled(value)
        @hash["enabled"] = value
      end

      def display(value)
        @hash["display"] = value.to_s
      end

      def max_visible_pinned(value)
        @hash["max_visible_pinned"] = value
      end

      def to_hash
        @hash
      end
    end
  end
end
