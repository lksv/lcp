require "active_model"

module LcpRuby
  module DataSource
    # Concern included into API-backed model classes (instead of ActiveRecord::Base).
    # Provides ActiveModel compatibility and data source delegation.
    module ApiModelConcern
      extend ActiveSupport::Concern

      included do
        include ActiveModel::Model
        include ActiveModel::Attributes
        include ActiveModel::Serialization

        class_attribute :lcp_data_source, instance_writer: false
        class_attribute :lcp_model_definition, instance_writer: false

        attribute :id, :string

        # Override ActiveModel::API#persisted? which always returns false
        define_method(:persisted?) do
          @persisted == true || id.present?
        end
      end

      class_methods do
        def lcp_api_model?
          true
        end

        # Find a single record by ID via the data source.
        def find(id)
          record = lcp_data_source.find(id)
          raise DataSource::RecordNotFound, "#{name} with id=#{id} not found" unless record
          record
        end

        # Find multiple records by IDs via the data source.
        def find_many(ids)
          lcp_data_source.find_many(ids)
        end

        # Search records via the data source.
        def lcp_search(filters: [], sort: nil, page: 1, per: 25)
          lcp_data_source.search(filters, sort: sort, page: page, per: per)
        end

        # Fetch select options via the data source.
        def lcp_select_options(search: nil, filter: {}, sort: nil, label_method: "to_label", limit: 200)
          lcp_data_source.select_options(
            search: search, filter: filter, sort: sort,
            label_method: label_method, limit: limit
          )
        end

        # Pundit compatibility — API models use a simple model name
        def model_name
          @_lcp_model_name ||= ActiveModel::Name.new(self, LcpRuby::Dynamic, name.demodulize)
        end

        # Policy lookup key for Pundit
        def policy_class
          Authorization::PolicyFactory.policy_for(lcp_model_definition.name)
        end

        # Ransack compatibility stubs (API models don't support Ransack)
        def ransackable_attributes(_auth_object = nil)
          []
        end

        def ransackable_associations(_auth_object = nil)
          []
        end

        def ransack(_params = {}, _options = {})
          nil
        end

        # AR compatibility stubs for controller/view code
        def column_names
          lcp_model_definition.fields.map(&:name)
        end

        def table_name
          lcp_model_definition.table_name
        end

        def all
          self
        end

        def none
          []
        end
      end

      def to_param
        id&.to_s
      end

      def to_label
        to_s
      end

      def read_attribute(attr_name)
        send(attr_name) if respond_to?(attr_name)
      end

      def [](attr_name)
        read_attribute(attr_name)
      end

      def error?
        false
      end

      # AR compatibility for views
      def new_record?
        !persisted?
      end

      def destroyed?
        false
      end

      def marked_for_destruction?
        false
      end
    end
  end
end
