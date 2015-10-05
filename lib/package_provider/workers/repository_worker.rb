require 'package_provider/repository_connection_pool'
require 'package_provider/repository_config'
require 'package_provider/repository_request'

# Package provider module
module PackageProvider
  # class performing caching repository as background job
  class RepositoryWorker
    include Sidekiq::Worker
    sidekiq_options queue: :clone_repository,
                    retry: PackageProvider.config.sidekiq.clone_retry_on_error

    def perform(request_as_json)
      request = PackageProvider::RepositoryRequest.from_json(request_as_json)
      PackageProvider.logger.info(
        "performing clonning: #{request.to_tsd} #{request.fingerprint}")

      repo_config = PackageProvider::RepositoryConfig.find(request.repo)
      c_pool = ReposPool.fetch(request.repo)

      PackageProvider.logger.debug("pool #{c_pool.inspect}")

      c_pool.with(timeout: repo_config[:timeout]) do |i|
        begin
          i.cached_clone(request)
        rescue PackageProvider::CachedRepository::CloneInProgress
          PackageProvider.logger.info("clone in progress: #{request.to_tsd}")
        end
      end
      PackageProvider.logger.info("clonning done #{request.to_tsd}")
    end
  end
end
