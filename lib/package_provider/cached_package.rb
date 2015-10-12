require 'timeout'
require 'package_provider/cached_repository'
require 'package_provider/package_packer'
require 'package_provider/repository_config'

module PackageProvider
  # Class representing cached repository to avoid multiple cloninng
  class CachedPackage
    class PackingInProgress < StandardError
    end

    PACKAGE_READY = '.package_ready'
    PACKAGE_CLONE_LOCK = '.package_clone_lock'
    ERROR = '.error'

    class << self
      def from_cache(package_request_or_fingerprint)
        return nil unless package_ready?(package_request_or_fingerprint)
        Metriks.meter('packageprovider.package.cached').mark
        path_to_package(package_request_or_fingerprint)
      end

      def package_ready?(package_request_or_fingerprint)
        path = package_path(package_request_or_fingerprint)

        Dir.exist?(path) && File.exist?("#{path + PACKAGE_READY}") &&
          File.exist?(File.join(path, 'package.zip')) &&
          !File.exist?("#{path + PACKAGE_CLONE_LOCK}")
      end

      def package_path(package_request_or_fingerprint)
        fp = package_request_fingerprint(package_request_or_fingerprint)
        File.join(
          PackageProvider.config.package_cache_root,
          fp)
      end

      def errors(package_request_or_fingerprint)
        fp = package_request_fingerprint(package_request_or_fingerprint)
        file_path = File.join("#{package_path(fp) + ERROR}")
        File.read(file_path) if File.exist?(file_path)
      end

      private

      def path_to_package(package_request_or_fingerprint)
        fp = package_request_fingerprint(package_request_or_fingerprint)
        File.join(package_path(fp), 'package.zip')
      end

      def package_request_fingerprint(package_request_or_fingerprint)
        if package_request_or_fingerprint.respond_to?(:fingerprint)
          package_request_or_fingerprint.fingerprint
        else
          package_request_or_fingerprint
        end
      end
    end

    attr_reader :package_request

    def initialize(package_request)
      @package_request = package_request
      @path = CachedPackage.package_path(@package_request.fingerprint)
      @locked_package_file = nil
    end

    def cache_package
      lock_package
      return if File.exist?("#{@path + PACKAGE_READY}")
      begin
        FileUtils.mkdir_p(@path)
        pack
        package_ready!
      rescue => err
        PackageProvider.logger.error("Create package failed: #{err}")
        FileUtils.rm_rf(@path)
      end
    ensure
      unlock_package
    end

    private

    def logger
      PackageProvider.logger
    end

    def pack
      packer = PackageProvider::PackagePacker.new(@path)
      error = ''
      @package_request.each do |req|
        checkout_dir = PackageProvider::CachedRepository.cache_dir(req)

        error += load_error(checkout_dir, req)

        req.folder_override.each do |fo|
          packer.add_folder(checkout_dir, fo)
        end
      end

      error.empty? ? packer.flush : package_error!(error)
    end

    def package_ready!
      FileUtils.touch("#{@path + PACKAGE_READY}")
    end

    def package_error!(message)
      File.open("#{@path + ERROR}", 'w+') do |f|
        f.puts(message)
      end
    end

    def lock_package
      Timeout.timeout(2) do
        file = "#{@path + PACKAGE_CLONE_LOCK}"
        locked_file = File.open(file, File::RDWR | File::CREAT, 0644)
        locked_file.flock(File::LOCK_EX)
        logger.info("Lock package #{file}")
        @locked_package_file = locked_file
      end
    rescue Timeout::Error
      Metriks.meter('packageprovider.package.locked').mark
      raise PackingInProgress
    end

    def unlock_package
      logger.info('Unlocking package')
      return unless @locked_package_file
      logger.info("Delete file #{@locked_package_file.path}")
      File.delete(@locked_package_file.path)
    end

    def load_error(path, req)
      file_path = "#{path + ERROR}"
      File.exist?(file_path) ? req.to_tsd + ":\n" + File.read(file_path) : ''
    end
  end
end
