require 'vcr'

VCR.configure do |config|
  config.cassette_library_dir = 'spec/vcr_cassettes'
  config.hook_into :webmock
  config.filter_sensitive_data('<GENIUS_API_KEY>') { ENV['GENIUS_API_KEY'] }
  config.configure_rspec_metadata!
  config.ignore_localhost = true
end
