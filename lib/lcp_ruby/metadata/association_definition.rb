module LcpRuby
  module Metadata
    class AssociationDefinition
      VALID_TYPES = %w[belongs_to has_many has_one].freeze

      attr_reader :type, :name, :target_model, :class_name, :foreign_key,
                  :dependent, :required

      def initialize(attrs = {})
        @type = attrs[:type].to_s
        @name = attrs[:name].to_s
        @target_model = attrs[:target_model]&.to_s
        @class_name = attrs[:class_name]
        @foreign_key = attrs[:foreign_key]&.to_s || infer_foreign_key
        @dependent = attrs[:dependent]&.to_sym
        @required = attrs.fetch(:required, @type == "belongs_to")

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
          required: hash["required"]
        )
      end

      def lcp_model?
        target_model.present?
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

      def validate!
        raise MetadataError, "Association type '#{@type}' is invalid" unless VALID_TYPES.include?(@type)
        raise MetadataError, "Association name is required" if @name.blank?
        if @target_model.blank? && @class_name.blank?
          raise MetadataError, "Association '#{@name}' requires either target_model or class_name"
        end
      end
    end
  end
end
