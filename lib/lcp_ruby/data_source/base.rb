module LcpRuby
  module DataSource
    class ReadonlyError < LcpRuby::Error; end
    class ConnectionError < LcpRuby::Error; end
    class RecordNotFound < LcpRuby::Error; end

    # Abstract base class defining the data source contract.
    # All data source adapters (RestJson, Host, etc.) must implement this interface.
    class Base
      # Find a single record by ID.
      # @param id [String, Integer] the record identifier
      # @return [Object] the record
      # @raise [RecordNotFound] if not found
      def find(id)
        raise NotImplementedError, "#{self.class}#find must be implemented"
      end

      # Find multiple records by IDs.
      # Default implementation calls find sequentially.
      # @param ids [Array<String, Integer>] the record identifiers
      # @return [Array<Object>] the records (missing IDs omitted)
      def find_many(ids)
        ids.filter_map do |id|
          find(id)
        rescue RecordNotFound
          nil
        end
      end

      # Search for records with filtering, sorting, and pagination.
      # @param params [Hash] filter parameters
      # @param sort [Hash, nil] e.g. { field: "name", direction: "asc" }
      # @param page [Integer] page number (1-based)
      # @param per [Integer] records per page
      # @return [SearchResult]
      def search(params = {}, sort: nil, page: 1, per: 25)
        raise NotImplementedError, "#{self.class}#search must be implemented"
      end

      # Count records matching the given parameters.
      # @param params [Hash] filter parameters
      # @return [Integer]
      def count(params = {})
        result = search(params, page: 1, per: 1)
        result.total_count
      end

      # Fetch options for association select dropdowns.
      # @param search [String, nil] text search query
      # @param filter [Hash] filter criteria
      # @param sort [Hash, nil] sort configuration
      # @param label_method [String] method name for display label
      # @param limit [Integer] max results
      # @return [Array<Hash>] array of { id:, label: } hashes
      def select_options(search: nil, filter: {}, sort: nil, label_method: "to_label", limit: 200)
        result = self.search(filter, sort: sort, page: 1, per: limit)
        result.map do |record|
          {
            id: record.id,
            label: record.respond_to?(label_method) ? record.send(label_method).to_s : record.to_s
          }
        end
      end

      # Write operations — Phase 1 is read-only
      def save(_record)
        raise ReadonlyError, "#{self.class} is read-only (Phase 1)"
      end

      def destroy(_id)
        raise ReadonlyError, "#{self.class} is read-only (Phase 1)"
      end

      def writable?
        false
      end

      # Returns the set of filter operators this data source supports.
      # Subclasses can override to restrict operators.
      def supported_operators
        %w[eq not_eq cont lt lteq gt gteq in null not_null start end]
      end
    end
  end
end
