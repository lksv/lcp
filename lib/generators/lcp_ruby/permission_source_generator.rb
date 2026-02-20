# frozen_string_literal: true

require "rails/generators"

module LcpRuby
  module Generators
    class PermissionSourceGenerator < Rails::Generators::Base
      source_root File.expand_path("templates/permission_source", __dir__)

      desc "Generates metadata files for the permission_config model, presenter, permissions, and view group"

      VALID_FORMATS = %w[dsl yaml].freeze

      class_option :format, type: :string, default: "dsl",
        desc: "Output format: dsl (Ruby DSL) or yaml"

      def validate_format
        fmt = options[:format].to_s
        unless VALID_FORMATS.include?(fmt)
          raise Thor::Error, "Invalid format '#{fmt}'. Must be one of: #{VALID_FORMATS.join(', ')}"
        end
      end

      def copy_model
        if yaml_format?
          template "model.yml", "config/lcp_ruby/models/permission_config.yml"
        else
          template "model.rb", "config/lcp_ruby/models/permission_config.rb"
        end
      end

      def copy_presenter
        if yaml_format?
          template "presenter.yml", "config/lcp_ruby/presenters/permission_configs.yml"
        else
          template "presenter.rb", "config/lcp_ruby/presenters/permission_configs.rb"
        end
      end

      def copy_permissions
        template "permissions.yml", "config/lcp_ruby/permissions/permission_config.yml"
      end

      def copy_view_group
        if yaml_format?
          template "view_group.yml", "config/lcp_ruby/views/permission_configs.yml"
        else
          template "view_group.rb", "config/lcp_ruby/views/permission_configs.rb"
        end
      end

      def update_initializer
        initializer_path = "config/initializers/lcp_ruby.rb"
        return unless File.exist?(initializer_path)

        content = File.read(initializer_path)
        return if content.include?("permission_source")

        inject_into_file initializer_path, after: /LcpRuby\.configure do \|config\|.*\n/ do
          "  config.permission_source = :model\n"
        end
      end

      def show_post_install_message
        say ""
        say "LCP Ruby permission source model installed!", :green
        say ""
        say "Generated files:"
        if yaml_format?
          say "  - config/lcp_ruby/models/permission_config.yml"
          say "  - config/lcp_ruby/presenters/permission_configs.yml"
        else
          say "  - config/lcp_ruby/models/permission_config.rb"
          say "  - config/lcp_ruby/presenters/permission_configs.rb"
        end
        say "  - config/lcp_ruby/permissions/permission_config.yml"
        if yaml_format?
          say "  - config/lcp_ruby/views/permission_configs.yml"
        else
          say "  - config/lcp_ruby/views/permission_configs.rb"
        end
        say ""
        say "Next steps:"
        say "  1. Add config.permission_source = :model to your initializer (if not auto-injected)"
        say "  2. Start server:    rails s"
        say "  3. Navigate to /permission-configs to manage permission definitions"
        say ""
      end

      private

      def yaml_format?
        options[:format].to_s == "yaml"
      end
    end
  end
end
