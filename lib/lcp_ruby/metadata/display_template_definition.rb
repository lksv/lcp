module LcpRuby
  module Metadata
    class DisplayTemplateDefinition
      attr_reader :name, :template, :subtitle, :icon, :badge,
                  :renderer, :partial, :options

      def initialize(attrs = {})
        @name = attrs[:name].to_s
        @template = attrs[:template]
        @subtitle = attrs[:subtitle]
        @icon = attrs[:icon]
        @badge = attrs[:badge]
        @renderer = attrs[:renderer]
        @partial = attrs[:partial]
        @options = attrs[:options] || {}

        validate!
      end

      def self.from_hash(name, hash)
        new(
          name: name,
          template: hash["template"],
          subtitle: hash["subtitle"],
          icon: hash["icon"],
          badge: hash["badge"],
          renderer: hash["renderer"],
          partial: hash["partial"],
          options: hash["options"] || {}
        )
      end

      def form
        if @renderer
          :renderer
        elsif @partial
          :partial
        else
          :structured
        end
      end

      def structured?
        form == :structured
      end

      def renderer?
        form == :renderer
      end

      def partial?
        form == :partial
      end

      # Extract {field} references from template, subtitle, badge strings.
      # Returns an array of unique field path strings.
      def referenced_fields
        @referenced_fields ||= begin
          strings = [ @template, @subtitle, @badge ].compact
          strings.flat_map { |s| s.scan(/\{([^}]+)\}/).flatten.map(&:strip) }.uniq
        end
      end

      private

      def validate!
        raise MetadataError, "Display template name is required" if @name.blank?
        raise MetadataError, "Display template '#{@name}' must have template, renderer, or partial" if @template.nil? && @renderer.nil? && @partial.nil?
      end
    end
  end
end
