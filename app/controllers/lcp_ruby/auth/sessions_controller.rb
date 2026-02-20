# frozen_string_literal: true

module LcpRuby
  module Auth
    class SessionsController < Devise::SessionsController
      include BaseController

      protected

      def after_sign_in_path_for(_resource)
        stored_location_for(:user) || LcpRuby.configuration.auth_after_login_path || lcp_ruby.root_path
      end

      def after_sign_out_path_for(_resource_or_scope)
        LcpRuby.configuration.auth_after_logout_path || lcp_ruby.new_user_session_path
      end
    end
  end
end
