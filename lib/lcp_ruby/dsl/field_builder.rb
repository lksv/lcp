module LcpRuby
  module Dsl
    class FieldBuilder
      attr_reader :validations

      def initialize
        @validations = []
      end

      def validates(type, **options)
        validation = { "type" => type.to_s }
        validator_class = options.delete(:validator_class)
        validation["validator_class"] = validator_class if validator_class
        validation["options"] = stringify_keys(options) unless options.empty?
        @validations << validation
      end

      private

      def stringify_keys(hash)
        HashUtils.stringify_deep(hash)
      end
    end
  end
end
