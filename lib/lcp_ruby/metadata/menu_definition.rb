module LcpRuby
  module Metadata
    class MenuDefinition
      attr_reader :top_menu, :sidebar_menu

      def initialize(top_menu: nil, sidebar_menu: nil)
        @top_menu = top_menu
        @sidebar_menu = sidebar_menu

        validate!
      end

      def self.from_hash(hash)
        data = hash["menu"] || hash

        top = data["top_menu"]&.map { |item| MenuItem.from_hash(item) }
        sidebar = data["sidebar_menu"]&.map { |item| MenuItem.from_hash(item) }

        new(top_menu: top, sidebar_menu: sidebar)
      end

      def has_top_menu?
        !top_menu.nil?
      end

      def has_sidebar_menu?
        !sidebar_menu.nil?
      end

      def top_only?
        has_top_menu? && !has_sidebar_menu?
      end

      def sidebar_only?
        !has_top_menu? && has_sidebar_menu?
      end

      def both?
        has_top_menu? && has_sidebar_menu?
      end

      # Returns the layout mode string for template selection
      def layout_mode
        if both?
          "both"
        elsif sidebar_only?
          "sidebar"
        else
          "top"
        end
      end

      private

      def validate!
        unless has_top_menu? || has_sidebar_menu?
          raise MetadataError, "Menu definition must have at least one of: top_menu, sidebar_menu"
        end
      end
    end
  end
end
