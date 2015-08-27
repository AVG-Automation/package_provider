$LOAD_PATH << 'lib'

require 'benchmark'
require 'package_provider'
require 'package_provider/repository'

# --------------------------- CONSTANTS-----------------------------------------
repo_url = ENV['REPO_URL']
commit_hash = ENV['COMMIT_HASH']
repo_local_cache = ENV['REPO_LOCAL_CACHE']
checkout_mask = ['/**']
checkout_mask = ENV['REPO_CHECKOUT_MASK'].split(',') if ENV['REPO_CHECKOUT_MASK']

$mutex = Mutex.new
PackageProvider.logger = Logger.new('log/debug.log')

$dest_dirs = []
$repos = []

puts 'preparing 10 repos into array'

THREADS = 6


def get_temp_dir_name(prefix)
  t = Dir.mktmpdir(prefix)
  FileUtils.rm_rf(t)
  t
end

def init_repos(count, repo_url: , repo_local_cache: nil)
  count.times do |i|
    $repos << PackageProvider::Repository.new(repo_url, repo_local_cache)
  end
end

def clone(threads, count, commit_hash:, checkout_mask:)
  threads = (0..(threads-1)).to_a.map do |thread_idx|
    Thread.new do
      count.times do |ii|
        # init dest dir, and remember it for deleting later
        dest_dir = get_temp_dir_name('pp_benchmark_')
        $mutex.synchronize { $dest_dirs << dest_dir }

        # clone repo
        $repos[thread_idx].clone( dest_dir, commit_hash, checkout_mask, false)
      end
    end
  end

  # finish when all threads are done
  threads.map(&:join)
end

begin
  Benchmark.bm do |x|
    x.report('init') { init_repos(THREADS, repo_url: repo_url, repo_local_cache: repo_local_cache) }
    x.report('clone-threads-1') { clone(1, 12, commit_hash: commit_hash, checkout_mask: checkout_mask) }
    x.report('clone-threads-2') { clone(2, 6, commit_hash: commit_hash, checkout_mask: checkout_mask) }
    x.report('clone-threads-3') { clone(3, 4, commit_hash: commit_hash, checkout_mask: checkout_mask) }
    x.report('clone-threads-4') { clone(4, 3, commit_hash: commit_hash, checkout_mask: checkout_mask) }
    #x.report('clone-threads-5') { clone(5, 3, commit_hash: commit_hash, checkout_mask: checkout_mask) }
    x.report('clone-threads-6') { clone(6, 2, commit_hash: commit_hash, checkout_mask: checkout_mask) }
  end

ensure
  $repos.map(&:destroy)
  $dest_dirs.each { |d| FileUtils.rm_rf(d) }
end
