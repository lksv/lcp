require "net/http"
require "json"
require "uri"

module LcpRuby
  module DataSource
    # REST/JSON data source adapter. Fetches records from an external REST API.
    class RestJson < Base
      attr_reader :config, :model_definition

      def initialize(config, model_definition)
        @config = config
        @model_definition = model_definition
        @field_mapping = config["field_mapping"] || {}
        @reverse_mapping = @field_mapping.invert
        @id_field = config["id_field"] || "id"
        @timeout = config["timeout"] || 30
      end

      def find(id)
        endpoint = record_endpoint(id)
        response = http_get(endpoint)
        data = navigate_response(response, config.dig("endpoints", "show", "response_path"))
        hydrate(data)
      rescue ConnectionError
        raise
      rescue => e
        raise RecordNotFound, "Record #{id} not found: #{e.message}"
      end

      def find_many(ids)
        batch_endpoint = config.dig("endpoints", "batch")
        if batch_endpoint
          url = build_url(batch_endpoint["path"], ids: ids.join(","))
          response = http_get(url)
          items = navigate_response(response, batch_endpoint["response_path"])
          Array(items).map { |item| hydrate(item) }
        else
          super
        end
      end

      def search(params = {}, sort: nil, page: 1, per: 25)
        endpoint_config = config.dig("endpoints", "search") || config.dig("endpoints", "index") || {}
        method = (endpoint_config["method"] || "GET").upcase

        query_params = build_search_params(params, sort: sort, page: page, per: per)

        if method == "POST"
          url = build_url(endpoint_config["path"] || collection_path)
          response = http_post(url, query_params)
        else
          url = build_url(collection_path, **query_params)
          response = http_get(url)
        end

        items = navigate_response(response, endpoint_config["response_path"] || config["response_path"])
        total = extract_total_count(response, endpoint_config, items)
        records = Array(items).map { |item| hydrate(item) }

        SearchResult.new(records: records, total_count: total, current_page: page, per_page: per)
      end

      def supported_operators
        config["supported_operators"] || super
      end

      private

      def collection_path
        config["resource"] || model_definition.name.pluralize
      end

      def record_endpoint(id)
        show_config = config.dig("endpoints", "show") || {}
        path = show_config["path"] || "#{collection_path}/#{id}"
        path = path.gsub(":id", id.to_s)
        build_url(path)
      end

      def build_url(path, **query_params)
        base = config["base_url"].to_s.chomp("/")
        full_path = path.start_with?("/") ? path : "/#{path}"
        uri = URI("#{base}#{full_path}")

        flat_params = query_params.reject { |_, v| v.nil? }
        uri.query = URI.encode_www_form(flat_params) if flat_params.any?
        uri.to_s
      end

      def build_search_params(filters, sort: nil, page: 1, per: 25)
        params = {}

        # Pagination
        pagination_config = config["pagination"] || {}
        style = pagination_config["style"] || "offset_limit"

        case style
        when "offset_limit"
          offset_param = pagination_config["offset_param"] || "offset"
          limit_param = pagination_config["limit_param"] || "limit"
          params[offset_param] = (page - 1) * per
          params[limit_param] = per
        when "page_number"
          page_param = pagination_config["page_param"] || "page"
          size_param = pagination_config["size_param"] || "per_page"
          params[page_param] = page
          params[size_param] = per
        when "cursor"
          limit_param = pagination_config["limit_param"] || "limit"
          params[limit_param] = per
        end

        # Sort
        if sort
          sort_param = pagination_config["sort_param"] || "sort"
          direction = sort[:direction] || "asc"
          field = map_field_name_to_remote(sort[:field])
          params[sort_param] = direction == "desc" ? "-#{field}" : field
        end

        # Filters
        filters.each do |filter|
          remote_field = map_field_name_to_remote(filter[:field])
          params[remote_field] = filter[:value]
        end if filters.is_a?(Array)

        params
      end

      def extract_total_count(response, endpoint_config, items)
        total_path = endpoint_config["total_count_path"] || config["total_count_path"]
        if total_path
          navigate_response(response, total_path).to_i
        else
          Array(items).size
        end
      end

      def navigate_response(data, path)
        return data unless path

        path.to_s.split(".").reduce(data) do |obj, key|
          if obj.is_a?(Hash)
            obj[key] || obj[key.to_sym]
          elsif obj.is_a?(Array) && key.match?(/\A\d+\z/)
            obj[key.to_i]
          else
            obj
          end
        end
      end

      def hydrate(data)
        return nil unless data.is_a?(Hash)

        model_class = LcpRuby.registry.model_for(model_definition.name)
        record = model_class.new

        # Map remote fields to local fields
        data.each do |remote_key, value|
          local_key = @reverse_mapping[remote_key.to_s] || remote_key.to_s

          # Map remote ID field to :id
          if remote_key.to_s == @id_field && @id_field != "id"
            record.id = value.to_s
            next
          end

          if record.respond_to?("#{local_key}=")
            record.send("#{local_key}=", value)
          end
        end

        # Ensure ID is set
        record.id = data[@id_field]&.to_s || data["id"]&.to_s if record.id.blank?

        record.instance_variable_set(:@persisted, true)
        record
      end

      def map_field_name_to_remote(field_name)
        @field_mapping[field_name.to_s] || field_name.to_s
      end

      # HTTP methods

      def http_get(url)
        uri = URI(url)
        request = Net::HTTP::Get.new(uri)
        apply_auth(request)
        execute_request(uri, request)
      end

      def http_post(url, body)
        uri = URI(url)
        request = Net::HTTP::Post.new(uri)
        request.content_type = "application/json"
        request.body = body.to_json
        apply_auth(request)
        execute_request(uri, request)
      end

      def execute_request(uri, request)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = @timeout
        http.read_timeout = @timeout

        response = http.request(request)

        unless response.is_a?(Net::HTTPSuccess)
          if response.code == "404"
            raise RecordNotFound, "HTTP 404: #{uri}"
          else
            raise ConnectionError, "HTTP #{response.code}: #{uri}"
          end
        end

        JSON.parse(response.body)
      rescue Timeout::Error, Errno::ECONNREFUSED, Errno::ECONNRESET, SocketError => e
        raise ConnectionError, "Connection failed: #{e.message} (#{uri})"
      rescue JSON::ParserError => e
        raise ConnectionError, "Invalid JSON response: #{e.message} (#{uri})"
      end

      def apply_auth(request)
        auth_config = config["auth"]
        return unless auth_config

        case auth_config["type"]
        when "bearer"
          token = ENV.fetch(auth_config["token_env"], nil)
          request["Authorization"] = "Bearer #{token}" if token
        when "basic"
          username = ENV.fetch(auth_config["username_env"], nil)
          password = ENV.fetch(auth_config["password_env"], nil)
          request.basic_auth(username, password) if username
        when "header"
          header_name = auth_config["header_name"] || "X-API-Key"
          value = ENV.fetch(auth_config["value_env"], nil)
          request[header_name] = value if value
        end
      end
    end
  end
end
