module LcpRuby
  module Metadata
    class ViewGroupDefinition
      VALID_SWITCHER_CONTEXTS = %w[index show form].freeze

      attr_reader :name, :model, :primary_presenter, :navigation_config, :views, :breadcrumb_config, :public, :raw_hash
      alias_method :public?, :public

      def initialize(attrs = {})
        @name = attrs[:name].to_s
        @model = attrs[:model].to_s
        @primary_presenter = attrs[:primary_presenter].to_s
        raw_nav = attrs.fetch(:navigation_config, {})
        @navigation_config = raw_nav == false ? false : HashUtils.stringify_deep(raw_nav || {})
        @views = (attrs[:views] || []).map { |v| HashUtils.stringify_deep(v) }
        @breadcrumb_config = parse_breadcrumb(attrs[:breadcrumb_config])
        @public = attrs[:public] == true
        @raw_hash = attrs[:raw_hash]
        @switcher = parse_switcher(attrs[:switcher_config])
        @presenter_diff_cache = {}

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

        nav = data["navigation"]
        navigation_config = nav == false ? false : (nav || {})

        new(
          name: data["name"],
          model: data["model"],
          primary_presenter: data["primary"],
          navigation_config: navigation_config,
          views: views,
          breadcrumb_config: data["breadcrumb"],
          public: data["public"],
          switcher_config: data["switcher"],
          raw_hash: data
        )
      end

      def switcher_config
        @switcher
      end

      def show_switcher?(context)
        return false if views.length < 2
        return false if @switcher == false

        case @switcher
        when Array then @switcher.include?(context.to_s)
        else presenters_differ_on?(context.to_s)
        end
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
        views.length > 1 && @switcher != false
      end

      # Returns false when navigation is explicitly disabled (navigation: false).
      # Used to exclude view groups from auto-generated navigation menus.
      def navigable?
        navigation_config != false
      end

      private

      def parse_switcher(value)
        case value
        when nil, "auto" then :auto
        when false then false
        when Array
          normalized = value.map(&:to_s)
          invalid = normalized - VALID_SWITCHER_CONTEXTS
          if invalid.any?
            raise MetadataError,
              "View group '#{@name}': invalid switcher contexts: #{invalid.join(', ')}. " \
              "Valid contexts are: #{VALID_SWITCHER_CONTEXTS.join(', ')}"
          end
          normalized
        else
          raise MetadataError,
            "View group '#{@name}': switcher must be false, 'auto', or an array of contexts"
        end
      end

      def presenters_differ_on?(context)
        unless VALID_SWITCHER_CONTEXTS.include?(context)
          raise ArgumentError,
            "Unknown switcher context '#{context}'. Valid contexts: #{VALID_SWITCHER_CONTEXTS.join(', ')}"
        end

        @presenter_diff_cache.fetch(context) do
          config_method = case context
                          when "index" then :index_config
                          when "show"  then :show_config
                          when "form"  then :form_config
                          end

          defs = presenter_definitions
          result = if defs.length < 2
            false
          else
            configs = defs.map(&config_method)
            !configs.all? { |c| c == configs.first }
          end

          @presenter_diff_cache[context] = result
        end
      end

      def presenter_definitions
        presenter_names.filter_map do |name|
          LcpRuby.loader.presenter_definitions[name]
        end
      end

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
