# frozen_string_literal: true

require "rails/generators"

module LcpRuby
  module Generators
    class SavedFiltersGenerator < Rails::Generators::Base
      source_root File.expand_path("templates/saved_filters", __dir__)

      desc "Generates YAML metadata files for saved filters (model, presenter, permissions)"

      def copy_saved_filter_model
        template "model.yml", "config/lcp_ruby/models/saved_filter.yml"
      end

      def copy_saved_filter_presenter
        template "presenter.yml", "config/lcp_ruby/presenters/saved_filters.yml"
      end

      def copy_saved_filter_permissions
        template "permissions.yml", "config/lcp_ruby/permissions/saved_filter.yml"
      end

      def copy_save_dialog_presenter
        template "save_dialog_presenter.yml", "config/lcp_ruby/presenters/save_filter_dialog.yml"
      end

      def show_post_install_message
        say ""
        say "LCP Ruby saved filters installed!", :green
        say ""
        say "Next steps:"
        say "  1. Start server:    rails s"
        say "  2. Enable saved filters in your presenter YAML:"
        say "     search:"
        say "       advanced_filter:"
        say "         saved_filters:"
        say "           enabled: true"
        say "  3. Navigate to /saved-filters to manage filters (admin)"
        say ""
        say "Optional:"
        say "  - Customize visibility_options, max_per_user, display mode in presenter YAML"
        say "  - Add auditing: true to the saved_filter model for change tracking"
        say ""
      end
    end
  end
end
