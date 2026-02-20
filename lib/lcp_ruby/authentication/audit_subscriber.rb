# frozen_string_literal: true

module LcpRuby
  module Authentication
    # Subscribes to Warden callbacks and emits ActiveSupport::Notifications
    # for authentication events (login, logout, failed login, account lock).
    #
    # Hooks are installed only when authentication mode is :built_in.
    module AuditSubscriber
      class << self
        def install!
          return unless LcpRuby::Authentication.built_in?

          Warden::Manager.after_authentication do |user, warden, opts|
            request = warden.request
            ActiveSupport::Notifications.instrument("authentication.lcp_ruby", {
              event: "login_success",
              user_id: user.id,
              email: user.email,
              ip: request.remote_ip,
              user_agent: request.user_agent
            })
          end

          Warden::Manager.before_failure do |env, opts|
            request = ActionDispatch::Request.new(env)
            ActiveSupport::Notifications.instrument("authentication.lcp_ruby", {
              event: "login_failure",
              email: request.params.dig("user", "email"),
              ip: request.remote_ip,
              user_agent: request.user_agent
            })
          end

          Warden::Manager.before_logout do |user, warden, opts|
            next unless user

            request = warden.request
            ActiveSupport::Notifications.instrument("authentication.lcp_ruby", {
              event: "logout",
              user_id: user.id,
              email: user.email,
              ip: request.remote_ip,
              user_agent: request.user_agent
            })
          end
        end
      end
    end
  end
end
