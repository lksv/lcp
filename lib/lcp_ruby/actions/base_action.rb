module LcpRuby
  module Actions
    class BaseAction
      attr_reader :record, :records, :current_user, :params, :model_class

      def initialize(context = {})
        @record = context[:record]
        @records = context[:records]
        @current_user = context[:current_user]
        @params = context[:params] || {}
        @model_class = context[:model_class]
      end

      def call
        raise NotImplementedError, "#{self.class}#call must be implemented"
      end

      # Override to define a form shown before execution (modal)
      def self.param_schema
        nil
      end

      # Override for visibility conditions beyond what YAML visible_when provides
      def self.visible?(_record, _user)
        true
      end

      # Override for extra authorization beyond permission YAML
      def self.authorized?(_record, _user)
        true
      end

      protected

      def success(message: nil, redirect_to: nil, data: nil)
        Result.new(success: true, message: message, redirect_to: redirect_to, data: data, errors: [])
      end

      def failure(message:, errors: [])
        Result.new(success: false, message: message, redirect_to: nil, data: nil, errors: errors)
      end
    end

    Result = Data.define(:success, :message, :redirect_to, :data, :errors) do
      def success? = success
      def failure? = !success
    end
  end
end
