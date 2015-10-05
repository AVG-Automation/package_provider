$LOAD_PATH << 'lib'

require 'bundler/setup'
require 'package_provider/app'

require 'sidekiq/web'
run Rack::URLMap.new(
  '/' => PackageProvider::App.new, '/sidekiq' => Sidekiq::Web)
