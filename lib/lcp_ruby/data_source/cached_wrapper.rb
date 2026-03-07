module LcpRuby
  module DataSource
    # Decorator that wraps any DataSource::Base with Rails.cache caching.
    # Supports separate TTL for individual records vs. list/search results.
    class CachedWrapper < Base
      attr_reader :inner, :model_name

      def initialize(inner, model_name:, ttl: 300, list_ttl: 60, stale_on_error: true)
        @inner = inner
        @model_name = model_name
        @ttl = ttl
        @list_ttl = list_ttl
        @stale_on_error = stale_on_error
      end

      def find(id)
        cache_key = record_cache_key(id)
        Rails.cache.fetch(cache_key, expires_in: @ttl) do
          @inner.find(id)
        end
      rescue ConnectionError => e
        return stale_record(id, cache_key) if @stale_on_error
        raise
      end

      def find_many(ids)
        @inner.find_many(ids)
      end

      def search(params = {}, sort: nil, page: 1, per: 25)
        cache_key = search_cache_key(params, sort, page, per)
        Rails.cache.fetch(cache_key, expires_in: @list_ttl) do
          @inner.search(params, sort: sort, page: page, per: per)
        end
      rescue ConnectionError => e
        return stale_search(cache_key) if @stale_on_error
        raise
      end

      def select_options(search: nil, filter: {}, sort: nil, label_method: "to_label", limit: 200)
        cache_key = select_options_cache_key(search, filter, sort, label_method, limit)
        Rails.cache.fetch(cache_key, expires_in: @list_ttl) do
          @inner.select_options(search: search, filter: filter, sort: sort, label_method: label_method, limit: limit)
        end
      rescue ConnectionError => e
        return [] if @stale_on_error
        raise
      end

      def count(params = {})
        @inner.count(params)
      end

      def writable?
        @inner.writable?
      end

      def supported_operators
        @inner.supported_operators
      end

      private

      def record_cache_key(id)
        "lcp_ruby/api/#{@model_name}/record/#{id}"
      end

      def search_cache_key(params, sort, page, per)
        hash = Digest::SHA256.hexdigest([ params, sort, page, per ].inspect)
        "lcp_ruby/api/#{@model_name}/search/#{hash}"
      end

      def select_options_cache_key(search, filter, sort, label_method, limit)
        hash = Digest::SHA256.hexdigest([ search, filter, sort, label_method, limit ].inspect)
        "lcp_ruby/api/#{@model_name}/options/#{hash}"
      end

      def stale_record(id, cache_key)
        stale = Rails.cache.read(cache_key)
        return stale if stale

        ApiErrorPlaceholder.new(id: id, model_name: @model_name)
      end

      def stale_search(cache_key)
        stale = Rails.cache.read(cache_key)
        if stale
          SearchResult.new(
            records: stale.records,
            total_count: stale.total_count,
            current_page: stale.current_page,
            per_page: stale.per_page,
            stale: true,
            message: "Data may be outdated"
          )
        else
          SearchResult.new(records: [], total_count: 0, error: true, message: "API unavailable")
        end
      end
    end
  end
end
