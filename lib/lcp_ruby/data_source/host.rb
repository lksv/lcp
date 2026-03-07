module LcpRuby
  module DataSource
    # Host adapter data source. Delegates to a host-app-provided class
    # that implements the DataSource::Base contract.
    class Host < Base
      attr_reader :provider

      def initialize(config, model_definition)
        provider_class_name = config["provider"]
        raise MetadataError, "Host data source requires 'provider' class name" unless provider_class_name

        @provider = provider_class_name.constantize.new
        @config = config
        @model_definition = model_definition

        validate_provider!
      end

      def find(id)
        @provider.find(id)
      end

      def find_many(ids)
        if @provider.respond_to?(:find_many)
          @provider.find_many(ids)
        else
          super
        end
      end

      def search(params = {}, sort: nil, page: 1, per: 25)
        @provider.search(params, sort: sort, page: page, per: per)
      end

      def count(params = {})
        if @provider.respond_to?(:count)
          @provider.count(params)
        else
          super
        end
      end

      def select_options(search: nil, filter: {}, sort: nil, label_method: "to_label", limit: 200)
        if @provider.respond_to?(:select_options)
          @provider.select_options(search: search, filter: filter, sort: sort, label_method: label_method, limit: limit)
        else
          super
        end
      end

      def supported_operators
        if @provider.respond_to?(:supported_operators)
          @provider.supported_operators
        else
          super
        end
      end

      private

      def validate_provider!
        %i[find search].each do |method|
          unless @provider.respond_to?(method)
            raise MetadataError,
              "Host data source provider #{@provider.class.name} must implement ##{method}"
          end
        end
      end
    end
  end
end
