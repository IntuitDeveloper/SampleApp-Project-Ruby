require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.cache_classes = false
  config.eager_load = false
  config.consider_all_requests_local = true

  config.server_timing = true

  # Allow ngrok hostnames
  config.hosts << /.*\.ngrok\.io/
  config.hosts << /.*\.ngrok-free\.app/

  config.action_controller.perform_caching = false
  config.active_support.deprecation = :log
  config.active_support.disallowed_deprecation = :raise
  config.active_support.disallowed_deprecation_warnings = []
  config.active_record.migration_error = :page_load if defined?(ActiveRecord)
  config.log_level = :debug
end


