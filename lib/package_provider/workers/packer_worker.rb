require 'active_support/time'
require 'package_provider/cached_repository'
require 'package_provider/cached_package'
require 'package_provider/workers/repository_worker'
require 'package_provider/request_parser/parser'

module PackageProvider
  # Class maintaining finishing package
  class PackerWorker
    include Sidekiq::Worker
    sidekiq_options queue: :package_packer,
                    retry: PackageProvider.config.sidekiq.packer_retry_on_error

    def perform(package_request_as_json)
      PackageProvider.logger.info(
        "Performing packing for: #{package_request_as_json}")

      parser = PackageProvider::Parser.new
      package_request = parser.parse_json(package_request_as_json)

      PackageProvider.logger.info(
        "Packing: #{package_request.to_tsd} #{package_request.fingerprint}")

      waiting_for_repo = false
      package_request.each do |req|
        waiting_for_repo ||= !request_ready_or_schedule(req)
      end

      if waiting_for_repo
        reschedule(package_request)
      else
        begin
          CachedPackage.new(package_request).cache_package
        rescue PackageProvider::CachedPackage::PackingInProgress
          PackageProvider.logger.info(
            "Packing in progress #{package_request.to_tsd}")
        end
      end
    end

    private

    def reschedule(package_request)
      PackageProvider.logger.info("packer reschedule #{package_request.to_tsd}")

      PackerWorker.perform_in(
        PackageProvider.config.sidekiq.packer_reschedule_time.seconds,
        package_request.to_json)
    end

    def request_ready_or_schedule(req)
      return true if PackageProvider::CachedRepository.cached?(req)
      return true if PackageProvider::CachedRepository.in_progress?(req)

      PackageProvider.logger.debug("scheduling clonning #{req.to_tsd}")

      PackageProvider::RepositoryWorker.perform_async(req.to_json)

      false
    end
  end
end
