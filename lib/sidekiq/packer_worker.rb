$LOAD_PATH << 'lib'
require 'sidekiq'
require 'package_provider'
require 'package_provider/workers/packer_worker'

PackageProvider.setup
PackageProvider.logger = Sidekiq.logger
