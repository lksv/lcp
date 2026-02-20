# frozen_string_literal: true

require_relative "authentication/devise_setup"
require_relative "authentication/audit_subscriber"

module LcpRuby
  module Authentication
    class << self
      def built_in?
        LcpRuby.configuration.authentication == :built_in
      end

      def none?
        LcpRuby.configuration.authentication == :none
      end

      def external?
        LcpRuby.configuration.authentication == :external
      end
    end
  end
end
