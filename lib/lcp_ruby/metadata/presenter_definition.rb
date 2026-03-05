module LcpRuby
  module Metadata
    class PresenterDefinition
      TILE_NAMED_FIELD_KEYS = %w[title_field subtitle_field description_field image_field].freeze

      attr_reader :name, :model, :label, :slug, :icon,
                  :index_config, :show_config, :form_config, :search_config,
                  :actions_config, :options, :raw_hash

      def initialize(attrs = {})
        @name = attrs[:name].to_s
        @model = attrs[:model].to_s
        @label = attrs[:label] || @name.humanize
        @slug = attrs[:slug]
        @icon = attrs[:icon]
        @index_config = HashUtils.stringify_deep(attrs[:index_config] || {})
        @show_config = HashUtils.stringify_deep(attrs[:show_config] || {})
        @form_config = HashUtils.stringify_deep(attrs[:form_config] || {})
        @search_config = HashUtils.stringify_deep(attrs[:search_config] || {})
        @actions_config = HashUtils.stringify_deep(attrs[:actions_config] || {})
        @options = HashUtils.stringify_deep(attrs[:options] || {})
        @raw_hash = attrs[:raw_hash]

        validate!
      end

      def self.from_hash(hash)
        new(
          name: hash["name"],
          model: hash["model"],
          label: hash["label"],
          slug: hash["slug"],
          icon: hash["icon"],
          index_config: hash["index"] || {},
          show_config: hash["show"] || {},
          form_config: hash["form"] || {},
          search_config: hash["search"] || {},
          actions_config: hash["actions"] || {},
          options: extract_options(hash),
          raw_hash: hash
        )
      end

      def routable?
        slug.present?
      end

      def read_only?
        options["read_only"] == true
      end

      def embeddable?
        options["embeddable"] == true
      end

      def reorderable?
        index_config["reorderable"] == true
      end

      def default_view
        index_config["default_view"] || "table"
      end

      def per_page
        index_config["per_page"] || 25
      end

      def table_columns
        index_config["table_columns"] || []
      end

      def collection_actions
        actions_config["collection"] || []
      end

      def single_actions
        actions_config["single"] || []
      end

      def batch_actions
        actions_config["batch"] || []
      end

      def scope
        raw_hash&.dig("scope")
      end

      def advanced_filter_config
        search_config["advanced_filter"] || {}
      end

      def advanced_filter_enabled?
        search_config["enabled"] && advanced_filter_config["enabled"] == true
      end

      def index_layout
        explicit = index_config["layout"]
        return explicit.to_sym if explicit

        return :tree if index_config["tree_view"] == true
        :table
      end

      def tree_view?
        index_layout == :tree
      end

      def tiles?
        index_layout == :tiles
      end

      def tile_config
        index_config["tile"] || {}
      end

      def sort_fields
        index_config["sort_fields"] || []
      end

      # Returns all field references from tile config (named slots + fields array).
      def all_tile_field_refs
        return [] unless tiles?

        tile = tile_config
        named = TILE_NAMED_FIELD_KEYS.filter_map { |k| tile[k] }
        extra = (tile["fields"] || []).filter_map { |f| f["field"] }
        named + extra
      end

      def per_page_options
        index_config["per_page_options"]
      end

      def summary_config
        index_config["summary"] || {}
      end

      def summary_enabled?
        summary_config["enabled"] == true
      end

      def default_expanded
        index_config.fetch("default_expanded", 0)
      end

      def reparentable?
        index_config["reparentable"] == true
      end

      def saved_filters_enabled?
        advanced_filter_config.dig("saved_filters", "enabled") == true
      end

      def saved_filters_config
        advanced_filter_config["saved_filters"] || {}
      end

      def item_classes
        @item_classes ||= index_config["item_classes"] || []
      end

      private

      def validate!
        raise MetadataError, "Presenter name is required" if @name.blank?
        raise MetadataError, "Presenter '#{@name}' requires a model reference" if @model.blank?
      end

      def self.extract_options(hash)
        {
          "read_only" => hash["read_only"],
          "embeddable" => hash["embeddable"],
          "redirect_after" => hash["redirect_after"],
          "empty_value" => hash["empty_value"]
        }.compact
      end
    end
  end
end
