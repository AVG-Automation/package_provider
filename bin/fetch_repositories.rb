$LOAD_PATH << 'lib'
require 'open3'
require 'benchmark'

require 'package_provider'
require 'package_provider/repository_config'

# Class maintaing update of local repositories
class RepositoryFetcher
  class NoRepositoriesToFetch < StandardError
  end

  def initialize(repos_to_fetch)
    @repos = normalize(repos_to_fetch)
    fail NoRepositoriesToFetch if @repos.size == 0
  end

  def fetch_all
    PackageProvider.logger.info(
      "Starting fetching total of #{@repos.size} repositories")

    time = Benchmark.realtime do
      @repos.each do |dir|
        PackageProvider.logger.info("Fetching: #{dir}")
        fetch(dir)
      end
    end

    PackageProvider.logger.info("Fetching finished in #{time} seconds")
    Metriks.timer('packageprovider.fetcher').update(time)
  end

  private

  def normalize(repos_to_fetch)
    repos_to_fetch.map do |repo|
      repo[1]['cache_dir']
    end.uniq.compact
  end

  def fetch(dir)
    o, e, s = Open3.capture3({}, 'git fetch --all', chdir: dir)

    if s.success?
      PackageProvider.logger.info("Fetch: #{dir} success.")
    else
      PackageProvider.logger.error("Fetch: #{dir} failed.")
      PackageProvider.logger.error("Fetch stdout: #{o}")
      PackageProvider.logger.error("Fetch stderr: #{e}")
      Metriks.meter('packageprovider.fetcher.error').mark
    end
    s.success?
  end
end

PackageProvider.setup

repository_fetcher = RepositoryFetcher.new(
  PackageProvider::RepositoryConfig.repositories)
repository_fetcher.fetch_all
