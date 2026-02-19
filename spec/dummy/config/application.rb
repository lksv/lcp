require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_view/railtie"
require "active_job/railtie"

Bundler.require(*Rails.groups)
require "lcp_ruby"

module Dummy
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f
    config.eager_load = false
    config.active_job.queue_adapter = :test
    config.action_controller.allow_forgery_protection = false
    config.active_storage.service = :test
  end
end
