module LcpRuby
  module Metadata
    class AssociationDefinition
      VALID_TYPES = %w[belongs_to has_many has_one].freeze
      NESTED_ATTRIBUTES_KEYS = %w[allow_destroy reject_if limit update_only].freeze

      attr_reader :type, :name, :target_model, :class_name, :foreign_key,
                  :dependent, :required, :inverse_of, :counter_cache, :touch,
                  :polymorphic, :as, :through, :source, :autosave, :validate,
                  :nested_attributes

      def initialize(attrs = {})
        @type = attrs[:type].to_s
        @name = attrs[:name].to_s
        @target_model = attrs[:target_model]&.to_s
        @class_name = attrs[:class_name]
        @foreign_key = attrs[:foreign_key]&.to_s || infer_foreign_key
        @dependent = attrs[:dependent]&.to_sym
        @required = attrs.fetch(:required, @type == "belongs_to")

        # Tier 1: simple pass-throughs
        @inverse_of = attrs[:inverse_of]&.to_sym
        @counter_cache = attrs[:counter_cache]
        @touch = attrs[:touch]

        # Tier 2: polymorphic
        @polymorphic = attrs.fetch(:polymorphic, false)
        @as = attrs[:as]&.to_s

        # Tier 2: through
        @through = attrs[:through]&.to_s
        @source = attrs[:source]&.to_s

        # Tier 2: autosave / validate
        @autosave = attrs[:autosave]
        @validate = attrs[:validate]

        # Nested attributes
        @nested_attributes = parse_nested_attributes(attrs[:nested_attributes])

        validate!
      end

      def self.from_hash(hash)
        new(
          type: hash["type"],
          name: hash["name"],
          target_model: hash["target_model"],
          class_name: hash["class_name"],
          foreign_key: hash["foreign_key"],
          dependent: hash["dependent"],
          required: hash["required"],
          inverse_of: hash["inverse_of"],
          counter_cache: hash["counter_cache"],
          touch: hash["touch"],
          polymorphic: hash["polymorphic"],
          as: hash["as"],
          through: hash["through"],
          source: hash["source"],
          autosave: hash["autosave"],
          validate: hash["validate"],
          nested_attributes: hash["nested_attributes"]
        )
      end

      def lcp_model?
        target_model.present?
      end

      def through?
        @through.present?
      end

      def resolved_class_name
        if lcp_model?
          "LcpRuby::Dynamic::#{target_model.camelize}"
        else
          class_name
        end
      end

      private

      def infer_foreign_key
        return nil unless @type == "belongs_to"

        "#{@name}_id"
      end

      def parse_nested_attributes(value)
        return nil unless value.is_a?(Hash)

        value = value.transform_keys(&:to_s)
        unknown_keys = value.keys - NESTED_ATTRIBUTES_KEYS
        if unknown_keys.any?
          Rails.logger.warn(
            "LcpRuby: Association '#{@name}' has unrecognized nested_attributes keys: " \
            "#{unknown_keys.join(', ')}. Valid keys: #{NESTED_ATTRIBUTES_KEYS.join(', ')}"
          )
        end

        result = {}
        NESTED_ATTRIBUTES_KEYS.each do |key|
          result[key] = value[key] if value.key?(key)
        end
        result.empty? ? nil : result
      end

      def validate!
        raise MetadataError, "Association type '#{@type}' is invalid" unless VALID_TYPES.include?(@type)
        raise MetadataError, "Association name is required" if @name.blank?
        unless @polymorphic || @as.present? || @through.present? || @target_model.present? || @class_name.present?
          raise MetadataError, "Association '#{@name}' requires target_model, class_name, polymorphic, as, or through"
        end
      end
    end
  end
end
