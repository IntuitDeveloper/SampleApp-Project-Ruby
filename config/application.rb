require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups) if defined?(Bundler)

module QuickbooksDemoRails
  class Application < Rails::Application
    config.load_defaults 8.0

    config.time_zone = "UTC"
    config.eager_load = false
  end
end


