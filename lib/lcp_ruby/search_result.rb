module LcpRuby
  # Kaminari-compatible value object for paginated search results from API data sources.
  # Wraps an array of records with pagination metadata so views/controllers can treat
  # it the same as an ActiveRecord paginated scope.
  class SearchResult
    include Enumerable

    attr_reader :records, :total_count, :current_page, :per_page, :message

    def initialize(records:, total_count:, current_page: 1, per_page: 25, error: false, stale: false, message: nil)
      @records = Array(records)
      @total_count = total_count.to_i
      @current_page = [ current_page.to_i, 1 ].max
      @per_page = [ per_page.to_i, 1 ].max
      @error = error
      @stale = stale
      @message = message
    end

    def each(&block)
      @records.each(&block)
    end

    def size
      @records.size
    end
    alias_method :length, :size

    def empty?
      @records.empty?
    end

    def to_a
      @records.dup
    end

    # Kaminari compatibility

    def total_pages
      return 0 if @total_count.zero?
      (@total_count.to_f / @per_page).ceil
    end

    def limit_value
      @per_page
    end

    def first_page?
      @current_page <= 1
    end

    def last_page?
      @current_page >= total_pages
    end

    def count
      @total_count
    end

    # Error state

    def error?
      @error == true
    end

    def stale?
      @stale == true
    end
  end
end
