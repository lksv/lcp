module LcpRuby
  module Metadata
    class PageDefinition
      VALID_LAYOUTS = %i[semantic grid].freeze

      attr_reader :name, :model, :slug, :dialog_config, :zones, :auto_generated, :layout, :title_key

      def initialize(attrs = {})
        @name = attrs[:name].to_s
        @model = attrs[:model]&.to_s.presence
        @slug = attrs[:slug]
        @dialog_config = HashUtils.stringify_deep(attrs[:dialog_config] || {})
        @zones = attrs[:zones] || []
        @auto_generated = !!attrs[:auto_generated]
        @layout = (attrs[:layout] || :semantic).to_sym
        @title_key = attrs[:title_key]&.to_s

        validate!
      end

      def self.from_hash(hash)
        hash = HashUtils.stringify_deep(hash)
        zones = (hash["zones"] || []).map { |z| ZoneDefinition.from_hash(z) }

        new(
          name: hash["name"],
          model: hash["model"],
          slug: hash["slug"],
          dialog_config: hash["dialog"] || {},
          zones: zones,
          auto_generated: hash["auto_generated"] || false,
          layout: hash["layout"] || :semantic,
          title_key: hash["title_key"]
        )
      end

      def routable?
        slug.present?
      end

      def auto_generated?
        @auto_generated
      end

      def standalone?
        @model.nil?
      end

      def grid?
        @layout == :grid
      end

      def dialog_only?
        !routable? && dialog_config.any?
      end

      def main_zone
        zones.find { |z| z.presenter_zone? && z.area == "main" } ||
          zones.find(&:presenter_zone?) ||
          zones.first
      end

      def main_presenter_name
        main_zone&.presenter
      end

      def title
        if @title_key.present?
          I18n.t(@title_key, default: @name.humanize)
        else
          @name.humanize
        end
      end

      def dialog_size
        dialog_config["size"] || "medium"
      end

      def dialog_closable?
        dialog_config.fetch("closable", true)
      end

      def dialog_title_key
        dialog_config["title_key"]
      end

      private

      def validate!
        raise MetadataError, "Page name is required" if @name.blank?
        raise MetadataError, "Page '#{@name}' must have at least one zone" if @zones.empty?

        unless VALID_LAYOUTS.include?(@layout)
          raise MetadataError, "Page '#{@name}' has invalid layout '#{@layout}'. Must be one of: #{VALID_LAYOUTS.join(', ')}"
        end
      end
    end
  end
end
