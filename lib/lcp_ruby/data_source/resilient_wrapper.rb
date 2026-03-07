module LcpRuby
  module DataSource
    # Decorator that catches connection errors and returns graceful fallbacks
    # instead of raising. Used as the outermost wrapper in the adapter chain.
    class ResilientWrapper < Base
      attr_reader :inner, :model_name

      def initialize(inner, model_name:)
        @inner = inner
        @model_name = model_name
      end

      def find(id)
        @inner.find(id)
      rescue ConnectionError => e
        log_error("find", id, e)
        ApiErrorPlaceholder.new(id: id, model_name: @model_name)
      end

      def find_many(ids)
        @inner.find_many(ids)
      rescue ConnectionError => e
        log_error("find_many", ids.inspect, e)
        ids.map { |id| ApiErrorPlaceholder.new(id: id, model_name: @model_name) }
      end

      def search(params = {}, sort: nil, page: 1, per: 25)
        @inner.search(params, sort: sort, page: page, per: per)
      rescue ConnectionError => e
        log_error("search", params.inspect, e)
        SearchResult.new(
          records: [], total_count: 0,
          current_page: page, per_page: per,
          error: true, message: e.message
        )
      end

      def count(params = {})
        @inner.count(params)
      rescue ConnectionError => e
        log_error("count", params.inspect, e)
        0
      end

      def select_options(search: nil, filter: {}, sort: nil, label_method: "to_label", limit: 200)
        @inner.select_options(search: search, filter: filter, sort: sort, label_method: label_method, limit: limit)
      rescue ConnectionError => e
        log_error("select_options", search.inspect, e)
        []
      end

      def writable?
        @inner.writable?
      end

      def supported_operators
        @inner.supported_operators
      end

      private

      def log_error(method, args, error)
        Rails.logger.error(
          "[LcpRuby::API] #{@model_name}.#{method}(#{args}) failed: #{error.class}: #{error.message}"
        )
      end
    end
  end
end
