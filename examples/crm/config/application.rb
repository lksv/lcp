require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "active_job/railtie"
require "active_storage/engine"
require "sprockets/railtie"

Bundler.require(*Rails.groups)
require "lcp_ruby"

module CrmApp
  class Application < Rails::Application
    config.load_defaults 7.1
    config.eager_load = false
    config.active_job.queue_adapter = :async

    config.secret_key_base = "crm_app_secret_key_base_for_development_only"
    config.active_storage.service = :local

    initializer "crm_app.ignore_lcp_services", before: :set_autoload_paths do
      %w[condition_services lcp_services actions event_handlers].each do |dir|
        path = Rails.root.join("app", dir)
        Rails.autoloaders.main.ignore(path) if path.directory?
      end
    end
  end
end
