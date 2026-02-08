module LcpRuby
  module Metadata
    class PresenterDefinition
      attr_reader :name, :model, :label, :slug, :icon,
                  :index_config, :show_config, :form_config, :search_config,
                  :actions_config, :navigation_config, :options

      def initialize(attrs = {})
        @name = attrs[:name].to_s
        @model = attrs[:model].to_s
        @label = attrs[:label] || @name.humanize
        @slug = attrs[:slug]
        @icon = attrs[:icon]
        @index_config = attrs[:index_config] || {}
        @show_config = attrs[:show_config] || {}
        @form_config = attrs[:form_config] || {}
        @search_config = attrs[:search_config] || {}
        @actions_config = attrs[:actions_config] || {}
        @navigation_config = attrs[:navigation_config] || {}
        @options = attrs[:options] || {}

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
          navigation_config: hash["navigation"] || {},
          options: extract_options(hash)
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

      private

      def validate!
        raise MetadataError, "Presenter name is required" if @name.blank?
        raise MetadataError, "Presenter '#{@name}' requires a model reference" if @model.blank?
      end

      def self.extract_options(hash)
        {
          "read_only" => hash["read_only"],
          "embeddable" => hash["embeddable"]
        }.compact
      end
    end
  end
end
