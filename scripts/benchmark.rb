$LOAD_PATH << 'lib'

require 'benchmark'
require 'package_provider'
require 'package_provider/repository'

def get_temp_dir_name(prefix)
  t = Dir.mktmpdir(prefix)
  FileUtils.rm_rf(t)
  t
end

puts 'benchmark started'

# --------------------------- CONSTANTS-----------------------------------------
repo_url = ENV['REPO_URL']
commit_hash = ENV['COMMIT_HASH']
repo_local_cache = ENV['REPO_LOCAL_CACHE']
repo_local_cache_fetched = ENV['REPO_LOCAL_CACHE_FETCHED']
checkout_mask = ['/**']
if ENV['REPO_CHECKOUT_MASK']
  checkout_mask = ENV['REPO_CHECKOUT_MASK'].split(',')
end

# ------------------------------ INIT  -----------------------------------------
mutex = Mutex.new
PackageProvider.logger = Logger.new('debug.log')
dest_dirs = []
not_fetched_repos = []
fetched_repos = []

puts 'preparing 10 repos into array'

Benchmark.bm do |x|
  x.report('init') do
    (0..4).map do
      not_fetched_repos << PackageProvider::Repository.new(
        repo_url, repo_local_cache)

      fetched_repos << PackageProvider::Repository.new(
        repo_url, repo_local_cache_fetched) if repo_local_cache_fetched
    end
  end
end

# ----------------------------- TEST not fetched -------------------------------

puts 'Starting benchmark with old repos'

Benchmark.bm do |x|
  x.report('') do
    threads = (0..4).map do |i|
      Thread.new do
        (0..4).map do |ii|
          dest_dir = get_temp_dir_name('pp_benchmark_')

          mutex.synchronize do
            dest_dirs << dest_dir
          end

          x.report("clone #{ii} for #{i}") do
            not_fetched_repos[0].clone(
              dest_dir, commit_hash, checkout_mask, false)
          end
        end
      end
    end
    threads.map(&:join)
  end
end

puts 'Starting benchmark with single old repo'

Benchmark.bm do |x|
  single_test_repo = PackageProvider::Repository.new(
    repo_url, repo_local_cache_fetched)

  x.report('') do
    t = Thread.new do
      (0..4).map do |ii|
        dest_dir = get_temp_dir_name('pp_benchmark_')

        mutex.synchronize do
          dest_dirs << dest_dir
        end

        x.report("clone #{ii}") do
          single_test_repo.clone(
            dest_dir, commit_hash, checkout_mask, false)
        end
      end
    end
    t.join
  end
  single_test_repo.destroy
end

# ----------------------------- TEST fetched -----------------------------------

if repo_local_cache_fetched
  puts 'Starting benchmark with fetched repo'

  Benchmark.bm do |x|
    x.report('') do
      threads = (0..4).map do |i|
        Thread.new do
          (0..4).map do |ii|
            dest_dir = get_temp_dir_name('pp_benchmark_')

            mutex.synchronize do
              dest_dirs << dest_dir
            end

            x.report("clone #{ii} for #{i}") do
              fetched_repos[i].clone(
                dest_dir, commit_hash, checkout_mask, false)
            end
          end
        end
      end
      threads.map(&:join)
    end
  end

  puts 'Starting benchmark with single fetched repo'

  Benchmark.bm do |x|
    single_test_repo = PackageProvider::Repository.new(
      repo_url, repo_local_cache_fetched)

    x.report('') do
      t = Thread.new do
        (0..4).map do |ii|
          dest_dir = get_temp_dir_name('pp_benchmark_')

          mutex.synchronize do
            dest_dirs << dest_dir
          end

          x.report("clone #{ii}") do
            new_fetched_repos[0].clone(
              dest_dir, commit_hash, checkout_mask, false)
          end
        end
      end
      t.join
    end
    single_test_repo.destroy
  end
end
# ------------------------------- CLEAR TEST -----------------------------------

not_fetched_repos.map(&:destroy)
fetched_repos.map(&:destroy)
dest_dirs.each { |d| FileUtils.rm_rf(d) }
