require "pundit"
require "ransack"
require "kaminari"
require "view_component"
require "turbo-rails"
require "stimulus-rails"

module LcpRuby
  class Engine < ::Rails::Engine
    isolate_namespace LcpRuby

    config.autoload_paths << root.join("lib")

    rake_tasks do
      load LcpRuby::Engine.root.join("lib", "tasks", "lcp_ruby.rake")
    end

    initializer "lcp_ruby.configuration" do
      LcpRuby.configuration.metadata_path ||= Rails.root.join("config", "lcp_ruby")
    end

    initializer "lcp_ruby.load_metadata", after: :load_config_initializers do
      ActiveSupport.on_load(:active_record) do
        LcpRuby::Engine.load_metadata!
      end
    end

    initializer "lcp_ruby.assets" do |app|
      app.config.assets.precompile += %w[lcp_ruby/application.css] if app.config.respond_to?(:assets)
    end

    class << self
      def load_metadata!
        return if @metadata_loaded

        Types::BuiltInServices.register_all!
        Types::BuiltInTypes.register_all!
        Services::BuiltInTransforms.register_all!
        Services::BuiltInDefaults.register_all!

        loader = LcpRuby.loader
        loader.load_all

        loader.model_definitions.each_value do |model_def|
          build_model(model_def)
        end

        Services::Registry.discover!(Rails.root.join("app").to_s)
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
