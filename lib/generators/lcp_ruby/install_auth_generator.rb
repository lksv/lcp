# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module LcpRuby
  module Generators
    class InstallAuthGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      desc "Sets up LCP Ruby built-in authentication (Devise-based)"

      def create_users_migration
        migration_template(
          "create_lcp_ruby_users.rb.erb",
          "db/migrate/create_lcp_ruby_users.rb"
        )
      end

      def add_devise_initializer
        return if File.exist?(Rails.root.join("config", "initializers", "devise.rb"))

        create_file "config/initializers/devise.rb", <<~RUBY
          # frozen_string_literal: true

          # Devise secret key — required for production.
          # Generate with: rails secret
          # Devise.secret_key = ENV["DEVISE_SECRET_KEY"]
        RUBY
      end

      def update_lcp_ruby_initializer
        initializer_path = "config/initializers/lcp_ruby.rb"

        unless File.exist?(Rails.root.join(initializer_path))
          create_file initializer_path, <<~RUBY
            # frozen_string_literal: true

            LcpRuby.configure do |config|
              config.authentication = :built_in
            end
          RUBY
          return
        end

        inject_into_file initializer_path, after: "LcpRuby.configure do |config|\n" do
          "  config.authentication = :built_in\n"
        end
      end

      def show_post_install_message
        say ""
        say "LCP Ruby authentication installed!", :green
        say ""
        say "Next steps:"
        say "  1. Run migrations:  rails db:migrate"
        say "  2. Create admin:    rake lcp_ruby:create_admin EMAIL=admin@example.com PASSWORD=changeme123"
        say "  3. Start server:    rails s"
        say ""
      end

      private

      def json_column_type
        if ActiveRecord::Base.connection.adapter_name.downcase.include?("postgresql")
          "jsonb"
        else
          "json"
        end
      rescue => _e
        # Fall back to json if database is not available during generation
        "json"
      end
    end
  end
end
