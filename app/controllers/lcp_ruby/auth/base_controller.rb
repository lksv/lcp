# frozen_string_literal: true

module LcpRuby
  module Auth
    # Shared base for all auth controllers.
    # Provides the built-in mode guard and common setup.
    module BaseController
      extend ActiveSupport::Concern

      included do
        layout "lcp_ruby/auth"

        skip_before_action :set_presenter_and_model, raise: false
        skip_before_action :authorize_presenter_access, raise: false

        before_action :require_built_in_auth!
      end

      private

      def require_built_in_auth!
        return if LcpRuby.configuration.authentication == :built_in

        raise ActionController::RoutingError, "Not Found"
      end
    end
  end
end
