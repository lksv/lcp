# frozen_string_literal: true

module LcpRuby
  module Auth
    class PasswordsController < Devise::PasswordsController
      include BaseController

      protected

      def after_resetting_password_path_for(_resource)
        LcpRuby.configuration.auth_after_login_path || lcp_ruby.root_path
      end
    end
  end
end
