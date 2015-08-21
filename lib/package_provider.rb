require 'logger'
require 'raven'
require 'metriks'
require 'metriks/reporter/graphite'

require 'package_provider/config'

# Namespace that handles git operations for PackageProvider
module PackageProvider
  class << self
    # rubocop:disable TrivialAccessors
    def logger
      @logger ||= Logger.new(STDOUT)
    end

    def logger=(l)
      @logger = l
    end
    # rubocop:enable TrivialAccessors
    def config
      @config ||= PackageProvider::Config.new
    end

    def root
      File.expand_path('../..', __FILE__)
    end

    def env
      system_env || 'development'
    end

    def setup
      logger.level = config.log_level || Logger::WARN
      setup_raven
      setup_metriks
    end

    private

    def system_env
      ENV['ENV'] || ENV['RACK_ENV'] || ENV['RAILS_ENV'] || ENV['APP_ENV']
    end

    def setup_raven
      ::Raven.configure do |config|
        config.dsn = PackageProvider.config.sentry_dsn
        config.environments = %w(production)
        config.current_environment = PackageProvider.env
        config.excluded_exceptions = %w(Sinatra::NotFound)
      end if config.sentry_dsn
    end

    def setup_metriks
      Metriks::Reporter::Graphite.new(
        config.graphite.host,
        config.graphite.port,
        config.graphite.options || {}
      ) if PackageProvider.config.graphite
    end
  end
end
