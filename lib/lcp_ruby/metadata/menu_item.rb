module LcpRuby
  module Metadata
    class MenuItem
      TYPES = %i[view_group link group separator].freeze

      attr_reader :type, :view_group_name, :label, :icon, :url, :children,
                  :visible_when, :position

      def initialize(type:, view_group_name: nil, label: nil, icon: nil, url: nil, children: [], visible_when: {}, position: nil)
        @type = type
        @view_group_name = view_group_name
        @label = label
        @icon = icon
        @url = url
        @children = children
        @visible_when = HashUtils.stringify_deep(visible_when || {})
        @position = position

        validate!
      end

      # Build a MenuItem from a parsed YAML hash.
      # Detection priority: separator > view_group > children > link
      def self.from_hash(hash)
        hash = HashUtils.stringify_deep(hash)

        if hash["separator"]
          return new(type: :separator)
        end

        if hash["view_group"]
          return new(
            type: :view_group,
            view_group_name: hash["view_group"].to_s,
            label: hash["label"],
            icon: hash["icon"],
            visible_when: hash["visible_when"] || {},
            position: hash["position"]
          )
        end

        if hash["children"]
          children = hash["children"].map { |child| from_hash(child) }
          return new(
            type: :group,
            label: hash["label"],
            icon: hash["icon"],
            children: children,
            visible_when: hash["visible_when"] || {},
            position: hash["position"]
          )
        end

        if hash["url"]
          return new(
            type: :link,
            label: hash["label"],
            icon: hash["icon"],
            url: hash["url"],
            visible_when: hash["visible_when"] || {},
            position: hash["position"]
          )
        end

        raise MetadataError, "Menu item must have one of: separator, view_group, children, or url"
      end

      # Resolve label from view group's primary presenter when not explicitly set
      def resolved_label(loader)
        return @label if @label.present?
        return nil unless view_group?

        presenter = primary_presenter(loader)
        presenter&.label
      end

      # Resolve icon from view group's primary presenter when not explicitly set
      def resolved_icon(loader)
        return @icon if @icon.present?
        return nil unless view_group?

        presenter = primary_presenter(loader)
        presenter&.icon
      end

      # Resolve slug from view group's primary presenter
      def resolved_slug(loader)
        return nil unless view_group?

        presenter = primary_presenter(loader)
        presenter&.slug
      end

      # Recursively check if this item or any descendant contains the given slug
      def contains_slug?(slug, loader)
        if view_group?
          vg = loader.view_group_definitions[view_group_name]
          return false unless vg

          all_slugs = vg.presenter_names.filter_map do |name|
            loader.presenter_definitions[name]&.slug
          end
          return true if all_slugs.include?(slug)
        end

        children.any? { |child| child.contains_slug?(slug, loader) }
      end

      def has_role_constraint?
        visible_when.is_a?(Hash) && visible_when["role"].present?
      end

      def allowed_roles
        return [] unless has_role_constraint?

        Array(visible_when["role"])
      end

      # Check if this item is visible given the user's roles
      def visible_to_roles?(user_roles)
        return true unless has_role_constraint?

        allowed_roles.any? { |r| user_roles.include?(r) }
      end

      def bottom?
        position.to_s == "bottom"
      end

      def view_group?
        type == :view_group
      end

      def link?
        type == :link
      end

      def group?
        type == :group
      end

      def separator?
        type == :separator
      end

      private

      def primary_presenter(loader)
        vg = loader.view_group_definitions[view_group_name]
        return nil unless vg

        loader.presenter_definitions[vg.primary_presenter]
      end

      def validate!
        unless TYPES.include?(type)
          raise MetadataError, "Invalid menu item type: #{type.inspect}"
        end

        case type
        when :group
          raise MetadataError, "Menu group requires a label" if @label.blank?
        when :link
          raise MetadataError, "Menu link requires a label" if @label.blank?
          raise MetadataError, "Menu link requires a url" if @url.blank?
        end
      end
    end
  end
end
