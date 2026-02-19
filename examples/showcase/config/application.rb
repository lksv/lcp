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

module ShowcaseApp
  class Application < Rails::Application
    config.load_defaults 7.1
    config.eager_load = false
    config.active_job.queue_adapter = :async

    config.secret_key_base = "showcase_app_secret_key_base_for_development_only"
    config.active_storage.service = :local
  end
end
