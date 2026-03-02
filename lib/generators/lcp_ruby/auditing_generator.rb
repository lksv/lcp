# frozen_string_literal: true

require "rails/generators"

module LcpRuby
  module Generators
    class AuditingGenerator < Rails::Generators::Base
      source_root File.expand_path("templates/auditing", __dir__)

      desc "Generates YAML metadata files for the audit log model (used by auditing: true on models)"

      def copy_model
        template "model.yml", "config/lcp_ruby/models/audit_log.yml"
      end

      def copy_presenter
        template "presenter.yml", "config/lcp_ruby/presenters/audit_logs.yml"
      end

      def copy_permissions
        template "permissions.yml", "config/lcp_ruby/permissions/audit_log.yml"
      end

      def copy_view_group
        template "view_group.yml", "config/lcp_ruby/views/audit_logs.yml"
      end

      def show_post_install_message
        say ""
        say "LCP Ruby audit log model installed!", :green
        say ""
        say "Next steps:"
        say "  1. Start server:    rails s"
        say "  2. Add auditing: true to any model YAML to enable change tracking"
        say "  3. Navigate to the Audit Logs section to view change history"
        say ""
      end
    end
  end
end
