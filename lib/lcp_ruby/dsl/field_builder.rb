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
        when_condition = options.delete(:when)
        validation["when"] = when_condition if when_condition
        field_ref = options.delete(:field_ref)
        validation["field_ref"] = field_ref.to_s if field_ref
        operator = options.delete(:operator)
        validation["operator"] = operator.to_s if operator
        message = options.delete(:message)
        validation["message"] = message if message
        service = options.delete(:service)
        validation["service"] = service.to_s if service
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
