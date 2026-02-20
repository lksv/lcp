# frozen_string_literal: true

require "rails/generators"

module LcpRuby
  module Generators
    class CustomFieldsGenerator < Rails::Generators::Base
      source_root File.expand_path("templates/custom_fields", __dir__)

      desc "Generates metadata files for the custom_field_definition model, presenter, permissions, and view group"

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
          template "model.yml", "config/lcp_ruby/models/custom_field_definition.yml"
        else
          template "model.rb", "config/lcp_ruby/models/custom_field_definition.rb"
        end
      end

      def copy_presenter
        if yaml_format?
          template "presenter.yml", "config/lcp_ruby/presenters/custom_fields.yml"
        else
          template "presenter.rb", "config/lcp_ruby/presenters/custom_fields.rb"
        end
      end

      def copy_permissions
        template "permissions.yml", "config/lcp_ruby/permissions/custom_field_definition.yml"
      end

      def copy_view_group
        if yaml_format?
          template "view_group.yml", "config/lcp_ruby/views/custom_fields.yml"
        else
          template "view_group.rb", "config/lcp_ruby/views/custom_fields.rb"
        end
      end

      def show_post_install_message
        say ""
        say "LCP Ruby custom fields model installed!", :green
        say ""
        say "Generated files:"
        if yaml_format?
          say "  - config/lcp_ruby/models/custom_field_definition.yml"
          say "  - config/lcp_ruby/presenters/custom_fields.yml"
        else
          say "  - config/lcp_ruby/models/custom_field_definition.rb"
          say "  - config/lcp_ruby/presenters/custom_fields.rb"
        end
        say "  - config/lcp_ruby/permissions/custom_field_definition.yml"
        if yaml_format?
          say "  - config/lcp_ruby/views/custom_fields.yml"
        else
          say "  - config/lcp_ruby/views/custom_fields.rb"
        end
        say ""
        say "Next steps:"
        say "  1. Enable custom_fields: true on models that need runtime fields"
        say "  2. Start server:    rails s"
        say "  3. Navigate to /<model_slug>/custom-fields to manage custom field definitions"
        say ""
      end

      private

      def yaml_format?
        options[:format].to_s == "yaml"
      end
    end
  end
end
