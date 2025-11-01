# frozen_string_literal: true

require 'vcr'

VCR.configure do |config|
  config.cassette_library_dir = 'spec/vcr_cassettes'
  config.hook_into :webmock
  config.filter_sensitive_data('<GENIUS_API_KEY>') { ENV.fetch('GENIUS_API_KEY', nil) }
  config.configure_rspec_metadata!
  config.ignore_localhost = true
end
