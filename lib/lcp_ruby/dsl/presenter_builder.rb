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
        @navigation_hash = nil
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

      # Navigation
      def navigation(menu:, position: nil)
        @navigation_hash = { "menu" => menu.to_s }
        @navigation_hash["position"] = position if position
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

        hash["navigation"] = @navigation_hash if @navigation_hash

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
        %w[name label slug icon read_only embeddable].each do |key|
          merged[key] = child_hash[key] if child_hash.key?(key)
        end

        # Section-level replace: child replaces parent entirely for these keys
        %w[index show form search actions navigation].each do |key|
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
        @default_view = nil
        @default_sort = nil
        @per_page_value = nil
        @views_available = nil
        @columns = []
        @row_click_value = nil
        @empty_message_value = nil
        @actions_position_value = nil
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

      def to_hash
        hash = {}
        hash["default_view"] = @default_view if @default_view
        hash["views_available"] = @views_available if @views_available
        hash["default_sort"] = @default_sort if @default_sort
        hash["per_page"] = @per_page_value if @per_page_value
        hash["table_columns"] = @columns unless @columns.empty?
        hash["row_click"] = @row_click_value if @row_click_value
        hash["empty_message"] = @empty_message_value if @empty_message_value
        hash["actions_position"] = @actions_position_value if @actions_position_value
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

      def to_fields
        @fields
      end
    end

    class ShowBuilder
      def initialize
        @layout = []
      end

      def section(title, columns: 1, responsive: nil, &block)
        section_hash = { "section" => title, "columns" => columns }
        section_hash["responsive"] = stringify_deep(responsive) if responsive
        if block
          builder = SectionBuilder.new
          builder.instance_eval(&block)
          section_hash["fields"] = builder.to_fields
        end
        @layout << section_hash
      end

      def association_list(title, association:)
        @layout << {
          "section" => title,
          "type" => "association_list",
          "association" => association.to_s
        }
      end

      def to_hash
        { "layout" => @layout }
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
      end

      def layout(value)
        @layout_value = value.to_s
      end

      def section(title, columns: 1, responsive: nil, collapsible: false, collapsed: false,
                  visible_when: nil, disable_when: nil, &block)
        section_hash = { "title" => title, "columns" => columns }
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

      def nested_fields(title, association:, allow_add: true, allow_remove: true,
                        min: nil, max: nil, add_label: nil, empty_message: nil,
                        sortable: false, columns: nil, visible_when: nil, disable_when: nil, &block)
        section_hash = {
          "title" => title,
          "type" => "nested_fields",
          "association" => association.to_s,
          "allow_add" => allow_add,
          "allow_remove" => allow_remove
        }
        section_hash["columns"] = columns if columns
        section_hash["min"] = min if min
        section_hash["max"] = max if max
        section_hash["add_label"] = add_label if add_label
        section_hash["empty_message"] = empty_message if empty_message
        section_hash["sortable"] = sortable if sortable
        section_hash["visible_when"] = stringify_deep(visible_when) if visible_when
        section_hash["disable_when"] = stringify_deep(disable_when) if disable_when
        if block
          builder = SectionBuilder.new
          builder.instance_eval(&block)
          section_hash["fields"] = builder.to_fields
        end
        @sections << section_hash
      end

      def to_hash
        hash = { "sections" => @sections }
        hash["layout"] = @layout_value if @layout_value
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

      def filter(name, label:, default: false, scope: nil)
        filter_hash = { "name" => name.to_s, "label" => label }
        filter_hash["default"] = true if default
        filter_hash["scope"] = scope.to_s if scope
        @filters << filter_hash
      end

      def to_hash
        hash = { "enabled" => @enabled }
        hash["searchable_fields"] = @searchable_fields_list if @searchable_fields_list
        hash["placeholder"] = @placeholder_value if @placeholder_value
        hash["predefined_filters"] = @filters unless @filters.empty?
        hash
      end
    end
  end
end
