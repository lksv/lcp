require "pundit"
require "ransack"
require "kaminari"
require "view_component"
require "turbo-rails"
require "stimulus-rails"
require "devise"

module LcpRuby
  class Engine < ::Rails::Engine
    isolate_namespace LcpRuby

    config.autoload_paths << root.join("lib")

    rake_tasks do
      load LcpRuby::Engine.root.join("lib", "tasks", "lcp_ruby.rake")
      load LcpRuby::Engine.root.join("lib", "tasks", "lcp_ruby_auth.rake")
    end

    initializer "lcp_ruby.i18n" do
      config.i18n.load_path += Dir[root.join("config", "locales", "**", "*.{rb,yml}")]
    end

    initializer "lcp_ruby.configuration" do
      LcpRuby.configuration.metadata_path ||= Rails.root.join("config", "lcp_ruby")
    end

    # Always set up Devise so that Warden middleware is properly configured.
    # This is needed because Devise is always a dependency and Warden middleware
    # is always in the stack. Only routes are conditional on :built_in mode.
    initializer "lcp_ruby.authentication", before: :add_routing_paths do |_app|
      LcpRuby::Authentication.setup_devise!
    end

    # Install Warden audit hooks after Devise middleware is loaded.
    config.after_initialize do
      LcpRuby::Authentication::AuditSubscriber.install!
    end

    initializer "lcp_ruby.ignore_renderers", before: :set_autoload_paths do |app|
      renderers_path = Rails.root.join("app", "renderers")
      if renderers_path.directory?
        Rails.autoloaders.main.ignore(renderers_path)
      end
    end

    initializer "lcp_ruby.load_metadata", after: :load_config_initializers do
      ActiveSupport.on_load(:active_record) do
        LcpRuby::Engine.load_metadata!
      end
    end

    initializer "lcp_ruby.assets" do |app|
      if app.config.respond_to?(:assets)
        app.config.assets.precompile += %w[
          lcp_ruby/application.css
          lcp_ruby/application.js
          lcp_ruby/tom-select.base.min.js
          lcp_ruby/tom-select.css
          lcp_ruby/activestorage.min.js
        ]
        app.config.assets.paths << root.join("app", "assets", "javascripts")
        app.config.assets.paths << root.join("app", "assets", "stylesheets")
        app.config.assets.paths << root.join("vendor", "assets", "javascripts")
        app.config.assets.paths << root.join("vendor", "assets", "stylesheets")
      end
    end

    class << self
      def load_metadata!
        return if @metadata_loaded

        Types::BuiltInTypes.register_all!
        Services::BuiltInTransforms.register_all!
        Services::BuiltInDefaults.register_all!
        Services::Registry.discover!(Rails.root.join("app").to_s)
        Display::RendererRegistry.register_built_ins!
        Display::RendererRegistry.discover!(Rails.root.join("app").to_s)

        loader = LcpRuby.loader
        loader.load_all

        loader.model_definitions.each_value do |model_def|
          build_model(model_def)
        end

        LcpRuby.check_services!

        @metadata_loaded = true
      end

      def reload!
        @metadata_loaded = false
        LcpRuby.reset!
        load_metadata!
      end

      private

      def build_model(model_def)
        schema_manager = ModelFactory::SchemaManager.new(model_def)
        schema_manager.ensure_table! if LcpRuby.configuration.auto_migrate

        builder = ModelFactory::Builder.new(model_def)
        model_class = builder.build

        LcpRuby.registry.register(model_def.name, model_class)
      end
    end
  end
end
