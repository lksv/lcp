# frozen_string_literal: true

module LcpRuby
  module Authentication
    class << self
      # Configures Devise when authentication mode is :built_in.
      # Called from the engine initializer before Devise loads its own routes.
      def setup_devise!
        require "devise"

        config = LcpRuby.configuration

        Devise.setup do |devise|
          devise.mailer_sender = config.auth_mailer_sender

          # Password settings
          devise.password_length = config.auth_password_min_length..128
          devise.email_regexp = /\A[^@\s]+@[^@\s]+\z/

          # Session timeout (nil = no timeout)
          devise.timeout_in = config.auth_session_timeout if config.auth_session_timeout

          # Lockable settings
          if config.auth_lock_after_attempts && config.auth_lock_after_attempts > 0
            devise.lock_strategy = :failed_attempts
            devise.unlock_strategy = :both
            devise.maximum_attempts = config.auth_lock_after_attempts
            devise.unlock_in = config.auth_lock_duration || 30.minutes
          end

          # Security
          devise.sign_out_via = :delete
          devise.strip_whitespace_keys = [ :email ]
          devise.stretches = Rails.env.test? ? 1 : 12

          # Turbo-compatible HTTP status codes
          devise.responder.error_status = :unprocessable_entity
          devise.responder.redirect_status = :see_other

          # ORM
          require "devise/orm/active_record"
        end
      end
    end
  end
end
