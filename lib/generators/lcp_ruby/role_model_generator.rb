# frozen_string_literal: true

require "rails/generators"

module LcpRuby
  module Generators
    class RoleModelGenerator < Rails::Generators::Base
      source_root File.expand_path("templates/role_model", __dir__)

      desc "Generates YAML metadata files for a DB-backed role model and enables role_source: :model"

      def copy_model
        template "model.yml", "config/lcp_ruby/models/role.yml"
      end

      def copy_presenter
        template "presenter.yml", "config/lcp_ruby/presenters/roles.yml"
      end

      def copy_permissions
        template "permissions.yml", "config/lcp_ruby/permissions/role.yml"
      end

      def copy_view_group
        template "view_group.yml", "config/lcp_ruby/views/roles.yml"
      end

      def update_lcp_ruby_initializer
        initializer_path = "config/initializers/lcp_ruby.rb"

        unless File.exist?(Rails.root.join(initializer_path))
          create_file initializer_path, <<~RUBY
            # frozen_string_literal: true

            LcpRuby.configure do |config|
              config.role_source = :model
            end
          RUBY
          return
        end

        inject_into_file initializer_path, after: "LcpRuby.configure do |config|\n" do
          "  config.role_source = :model\n"
        end
      end

      def show_post_install_message
        say ""
        say "LCP Ruby role model installed!", :green
        say ""
        say "Next steps:"
        say "  1. Start server:    rails s"
        say "  2. Navigate to the Roles section in your app to create roles"
        say "  3. Role names must match those used in your permissions YAML files"
        say ""
      end
    end
  end
end
