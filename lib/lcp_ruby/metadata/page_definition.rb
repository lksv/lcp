module LcpRuby
  module Metadata
    class PageDefinition
      attr_reader :name, :model, :slug, :dialog_config, :zones, :auto_generated

      def initialize(attrs = {})
        @name = attrs[:name].to_s
        @model = attrs[:model]&.to_s
        @slug = attrs[:slug]
        @dialog_config = HashUtils.stringify_deep(attrs[:dialog_config] || {})
        @zones = attrs[:zones] || []
        @auto_generated = !!attrs[:auto_generated]

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
          auto_generated: hash["auto_generated"] || false
        )
      end

      def routable?
        slug.present?
      end

      def auto_generated?
        @auto_generated
      end

      def dialog_only?
        !routable? && dialog_config.any?
      end

      def main_zone
        zones.find { |z| z.area == "main" } || zones.first
      end

      def main_presenter_name
        main_zone&.presenter
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
      end
    end
  end
end
