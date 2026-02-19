module LcpRuby
  module Metadata
    class ViewGroupDefinition
      attr_reader :name, :model, :primary_presenter, :navigation_config, :views, :breadcrumb_config

      def initialize(attrs = {})
        @name = attrs[:name].to_s
        @model = attrs[:model].to_s
        @primary_presenter = attrs[:primary_presenter].to_s
        @navigation_config = HashUtils.stringify_deep(attrs[:navigation_config] || {})
        @views = (attrs[:views] || []).map { |v| HashUtils.stringify_deep(v) }
        @breadcrumb_config = parse_breadcrumb(attrs[:breadcrumb_config])

        validate!
      end

      def self.from_hash(hash)
        data = hash["view_group"] || hash
        views = (data["views"] || []).map do |v|
          {
            "presenter" => v["presenter"].to_s,
            "label" => v["label"],
            "icon" => v["icon"]
          }.compact
        end

        new(
          name: data["name"],
          model: data["model"],
          primary_presenter: data["primary"],
          navigation_config: data["navigation"] || {},
          views: views,
          breadcrumb_config: data["breadcrumb"]
        )
      end

      def breadcrumb_enabled?
        @breadcrumb_config != false
      end

      def breadcrumb_relation
        return nil unless @breadcrumb_config.is_a?(Hash)
        @breadcrumb_config["relation"]
      end

      def presenter_names
        views.map { |v| v["presenter"] }
      end

      def primary?(presenter_name)
        primary_presenter == presenter_name.to_s
      end

      def view_for(presenter_name)
        views.find { |v| v["presenter"] == presenter_name.to_s }
      end

      def has_switcher?
        views.length > 1
      end

      private

      def parse_breadcrumb(value)
        case value
        when false then false
        when Hash then HashUtils.stringify_deep(value)
        when nil then nil
        else
          raise MetadataError, "View group '#{@name}': breadcrumb must be false or a Hash"
        end
      end

      def validate!
        raise MetadataError, "View group name is required" if @name.blank?
        raise MetadataError, "View group '#{@name}' requires a model reference" if @model.blank?
        raise MetadataError, "View group '#{@name}' requires at least one view" if @views.empty?
        raise MetadataError, "View group '#{@name}' requires a primary presenter" if @primary_presenter.blank?

        unless presenter_names.include?(@primary_presenter)
          raise MetadataError,
            "View group '#{@name}': primary presenter '#{@primary_presenter}' is not in the views list"
        end
      end
    end
  end
end
