# frozen_string_literal: true

require "rails/generators"

module LcpRuby
  module Generators
    class GroupsGenerator < Rails::Generators::Base
      source_root File.expand_path("templates/groups", __dir__)

      desc "Generates YAML metadata files for DB-backed groups and enables group_source: :model"

      def copy_group_model
        template "group_model.yml", "config/lcp_ruby/models/group.yml"
      end

      def copy_group_membership_model
        template "group_membership_model.yml", "config/lcp_ruby/models/group_membership.yml"
      end

      def copy_group_role_mapping_model
        template "group_role_mapping_model.yml", "config/lcp_ruby/models/group_role_mapping.yml"
      end

      def copy_group_presenter
        template "group_presenter.yml", "config/lcp_ruby/presenters/groups.yml"
      end

      def copy_group_permissions
        template "group_permissions.yml", "config/lcp_ruby/permissions/group.yml"
      end

      def copy_group_view_group
        template "group_view_group.yml", "config/lcp_ruby/views/groups.yml"
      end

      def update_lcp_ruby_initializer
        initializer_path = "config/initializers/lcp_ruby.rb"

        unless File.exist?(Rails.root.join(initializer_path))
          create_file initializer_path, <<~RUBY
            # frozen_string_literal: true

            LcpRuby.configure do |config|
              config.group_source = :model
              config.group_role_mapping_model = "group_role_mapping"
            end
          RUBY
          return
        end

        inject_into_file initializer_path, after: "LcpRuby.configure do |config|\n" do
          "  config.group_source = :model\n" \
          "  config.group_role_mapping_model = \"group_role_mapping\"\n"
        end
      end

      def show_post_install_message
        say ""
        say "LCP Ruby groups installed!", :green
        say ""
        say "Next steps:"
        say "  1. Start server:    rails s"
        say "  2. Navigate to the Groups section to create groups"
        say "  3. Create group memberships and role mappings"
        say "  4. Users will inherit roles from their group memberships"
        say ""
        say "Optional:"
        say "  - Remove group_role_mapping_model.yml and config line for membership-only groups (no role mapping)"
        say "  - Adjust role_resolution_strategy: :merged (default), :groups_only, or :direct_only"
        say ""
      end
    end
  end
end
