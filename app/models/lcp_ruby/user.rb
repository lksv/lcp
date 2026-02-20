# frozen_string_literal: true

# Ensure Devise ORM extension is loaded before the model class body is evaluated.
# This is also loaded inside Authentication.setup_devise!, but the model may be
# autoloaded before the engine initializer runs (e.g. by devise_for in routes).
require "devise/orm/active_record"

module LcpRuby
  class User < ActiveRecord::Base
    self.table_name = "lcp_ruby_users"

    # Devise modules — lockable and timeoutable are always declared but
    # their behavior depends on configuration (lock_after_attempts, session_timeout).
    devise :database_authenticatable, :registerable, :recoverable,
           :rememberable, :validatable, :trackable, :lockable, :timeoutable

    validates :name, presence: true

    scope :active, -> { where(active: true) }

    # Compatible with PermissionEvaluator role resolution.
    # The DB stores lcp_role as a JSON array; this ensures it's always an Array.
    def lcp_role
      Array(super)
    end

    # Extension point for custom profile fields stored in profile_data JSON.
    def profile
      (profile_data || {}).with_indifferent_access
    end

    # Devise Timeoutable — delegate timeout duration to configuration.
    def timeout_in
      LcpRuby.configuration.auth_session_timeout
    end

    # Devise Lockable — delegate max attempts to configuration.
    # Returns 0 when lockable is disabled (Devise treats 0 as unlimited).
    def lock_strategy_enabled?(strategy)
      return false if LcpRuby.configuration.auth_lock_after_attempts.to_i <= 0
      super
    end
  end
end
