# frozen_string_literal: true

module LcpRuby
  module Auth
    class RegistrationsController < Devise::RegistrationsController
      include BaseController

      before_action :check_registration_enabled, only: [ :new, :create ]

      protected

      def after_sign_up_path_for(_resource)
        LcpRuby.configuration.auth_after_login_path || lcp_ruby.root_path
      end

      def after_update_path_for(_resource)
        LcpRuby.configuration.auth_after_login_path || lcp_ruby.root_path
      end

      def sign_up_params
        params.require(:user).permit(:name, :email, :password, :password_confirmation)
      end

      def account_update_params
        params.require(:user).permit(:name, :email, :password, :password_confirmation, :current_password)
      end

      private

      def check_registration_enabled
        return if LcpRuby.configuration.auth_allow_registration

        raise ActionController::RoutingError, "Not Found"
      end
    end
  end
end
