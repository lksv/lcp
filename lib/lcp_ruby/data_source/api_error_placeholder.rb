module LcpRuby
  module DataSource
    # Placeholder object returned when an API record cannot be fetched.
    # Responds to common methods so views don't crash on API failures.
    class ApiErrorPlaceholder
      attr_reader :id, :model_name_str

      def initialize(id:, model_name: "Record")
        @id = id
        @model_name_str = model_name
      end

      def to_label
        "#{@model_name_str} ##{@id} (unavailable)"
      end

      def to_s
        to_label
      end

      def to_param
        @id.to_s
      end

      def persisted?
        true
      end

      def error?
        true
      end

      def respond_to_missing?(_method_name, _include_private = false)
        true
      end

      private

      def method_missing(_method_name, *_args)
        nil
      end
    end
  end
end
