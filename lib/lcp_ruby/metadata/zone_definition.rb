module LcpRuby
  module Metadata
    class ZoneDefinition
      VALID_WIDGET_TYPES = %w[kpi_card text list].freeze

      attr_reader :name, :presenter, :area, :type, :widget, :position, :scope, :limit, :visible_when

      def initialize(name:, presenter: nil, area: "main", type: :presenter, widget: nil,
                     position: nil, scope: nil, limit: nil, visible_when: nil)
        @name = name.to_s
        @presenter = presenter&.to_s
        @area = (area || "main").to_s
        @type = (type || :presenter).to_sym
        @widget = widget.is_a?(Hash) ? HashUtils.stringify_deep(widget) : nil
        @position = position.is_a?(Hash) ? HashUtils.stringify_deep(position) : nil
        @scope = scope&.to_s
        @limit = limit&.to_i
        @visible_when = visible_when.is_a?(Hash) ? HashUtils.stringify_deep(visible_when) : nil

        validate!
      end

      def self.from_hash(hash)
        hash = HashUtils.stringify_deep(hash)
        new(
          name: hash["name"],
          presenter: hash["presenter"],
          area: hash["area"],
          type: hash["type"] || :presenter,
          widget: hash["widget"],
          position: hash["position"],
          scope: hash["scope"],
          limit: hash["limit"],
          visible_when: hash["visible_when"]
        )
      end

      def widget?
        @type == :widget
      end

      def presenter_zone?
        @type == :presenter
      end

      def grid_position
        return {} unless @position

        style = {}
        style["grid-row"] = "#{@position['row']} / span #{@position['height'] || 1}" if @position["row"]
        style["grid-column"] = "#{@position['col']} / span #{@position['width'] || 1}" if @position["col"]
        style
      end

      private

      def validate!
        raise MetadataError, "Zone name is required" if @name.blank?

        if presenter_zone?
          raise MetadataError, "Zone '#{@name}' requires a presenter reference" if @presenter.blank?
        elsif widget?
          raise MetadataError, "Zone '#{@name}' requires a widget configuration" if @widget.nil?
          validate_widget!
        else
          raise MetadataError, "Zone '#{@name}' has invalid type '#{@type}'. Must be :presenter or :widget"
        end
      end

      def validate_widget!
        widget_type = @widget["type"]
        unless widget_type && VALID_WIDGET_TYPES.include?(widget_type)
          raise MetadataError,
            "Zone '#{@name}' widget requires a valid type (#{VALID_WIDGET_TYPES.join(', ')}), got '#{widget_type}'"
        end

        case widget_type
        when "kpi_card"
          raise MetadataError, "Zone '#{@name}' kpi_card widget requires 'model'" unless @widget["model"]
          raise MetadataError, "Zone '#{@name}' kpi_card widget requires 'aggregate'" unless @widget["aggregate"]
        when "text"
          raise MetadataError, "Zone '#{@name}' text widget requires 'content_key'" unless @widget["content_key"]
        when "list"
          raise MetadataError, "Zone '#{@name}' list widget requires 'model'" unless @widget["model"]
        end
      end
    end
  end
end
