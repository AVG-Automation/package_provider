describe PackageProvider::CachedPackage do
  cached_packages_test_path = Dir.mktmpdir('pp_unit_test')
  cached_repositories_test_path = Dir.mktmpdir('pp_unit_test')

  let(:package_request) { PackageProvider::PackageRequest.new }
  let(:repository_request) do
    req = PackageProvider::RepositoryRequest.new('repo', 'commit', nil)
    req.add_folder_override('docs')
    req
  end
  let(:package_request2) do
    req = PackageProvider::PackageRequest.new
    req << repository_request
    req
  end
  let(:subject) do
    PackageProvider::CachedPackage.new(package_request)
  end
  let(:subject2) do
    PackageProvider::CachedPackage.new(package_request)
  end
  let(:subject3) do
    PackageProvider::CachedPackage.new(package_request2)
  end

  before(:each) do
    FileUtils.rm_rf(cached_packages_test_path)
    FileUtils.rm_rf(cached_repositories_test_path)

    Dir.mkdir(cached_packages_test_path)
    Dir.mkdir(cached_repositories_test_path)

    allow(PackageProvider.config)
      .to receive(:package_cache_root) { cached_packages_test_path }
    allow(PackageProvider.config)
      .to receive(:repository_cache_root) { cached_repositories_test_path }
  end

  after(:all) do
    FileUtils.rm_rf(cached_packages_test_path)
    FileUtils.rm_rf(cached_repositories_test_path)
  end

  describe '#cache_package?' do
    it 'return archive on empty request' do
      subject.cache_package

      package_file = PackageProvider::CachedPackage.from_cache(package_request)

      expect(package_file).to match(/package.zip\Z/)
      expect(File.exist?(package_file)).to be true
    end

    it 'removes folder and .clone_lock file on error' do
      expect(subject).to receive(:pack) { fail 'Testing error' }
      subject.cache_package

      expect(PackageProvider::CachedPackage.from_cache(package_request))
        .to be nil

      path = PackageProvider::CachedRepository.cache_dir(repository_request)
      path << PackageProvider::CachedRepository::CLONE_LOCK

      expect(File.exist?(path)).to be false
    end

    it 'raises error when packing is in progress' do
      thread_ready = false
      t = Thread.new do
        expect(subject).to receive(:pack) do
          thread_ready = true
          Thread.pass
          sleep 3
        end
        subject.cache_package
      end

      Thread.pass until thread_ready

      expect { subject2.cache_package }.to raise_error(
        PackageProvider::CachedPackage::PackingInProgress)
      t.join
    end

    it 'sends message add_folder to package packer' do
      expect_any_instance_of(PackageProvider::PackagePacker)
        .to receive(:flush).once

      expect_any_instance_of(PackageProvider::ZipFileGenerator)
        .not_to receive(:add_folder)

      subject.cache_package
    end

    it 'creates error file when one of repositories has error' do
      path = PackageProvider::CachedRepository.cache_dir(repository_request)
      path << PackageProvider::CachedRepository::ERROR

      File.open(path, 'w+') do |f|
        f.puts('some error')
      end

      subject3.cache_package

      err_file_path = PackageProvider::CachedPackage.package_path(
        package_request2)

      expect(File.exist?(err_file_path)).to be true
    end
  end
end
