module LcpRuby
  module Pages
    class ScopeContextResolver
      DYNAMIC_PREFIX = ":"
      VALID_REFERENCES = %w[record_id current_user current_user_id current_year current_date].freeze
      RECORD_DOT_PATTERN = /\Arecord\.(.+)\z/
      MAX_DOT_PATH_DEPTH = 1

      def initialize(scope_context, record:, user:)
        @scope_context = scope_context
        @record = record
        @user = user
      end

      def resolve
        return {} if @scope_context.blank?

        @scope_context.each_with_object({}) do |(key, value), resolved|
          resolved[key] = resolve_value(value)
        end
      end

      private

      def resolve_value(value)
        return value unless value.is_a?(String) && value.start_with?(DYNAMIC_PREFIX)

        reference = value.delete_prefix(DYNAMIC_PREFIX)
        case reference
        when "record_id"
          @record&.id
        when RECORD_DOT_PATTERN
          resolve_dot_path(@record, $1)
        when "current_user"
          @user
        when "current_user_id"
          @user&.id
        when "current_year"
          Date.current.year
        when "current_date"
          Date.current
        else
          raise MetadataError, "Unknown scope_context reference: #{value}"
        end
      end

      def resolve_dot_path(object, path)
        segments = path.split(".")
        if segments.size > MAX_DOT_PATH_DEPTH
          raise MetadataError, "scope_context dot-path ':record.#{path}' exceeds maximum depth " \
                               "of #{MAX_DOT_PATH_DEPTH} (got #{segments.size})"
        end

        segments.reduce(object) do |obj, method|
          return nil unless obj.respond_to?(method)
          obj.public_send(method)
        end
      end
    end
  end
end
