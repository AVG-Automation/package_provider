describe 'Cached repository integration' do
  let(:fake_repo_dir) do
    File.join(PackageProvider.root, 'spec', 'factories', 'testing-repo')
    # if ur developing with vagrant on windows machine you need to
    # copy test repo (spec/factories/test-repo) to your
    # file system ex. /tmp/testing-repo to git clone fix
    # just comment line 6 and uncomment line below
    # File.join('/var/tmp/factories', 'testing-repo')
  end
  let(:repo) { PackageProvider::CachedRepository.new(fake_repo_dir) }
  let(:repo2) { PackageProvider::CachedRepository.new(fake_repo_dir) }
  let(:request) do
    req = PackageProvider::RepositoryRequest.new(
      fake_repo_dir, '9191ed1ad760d66e84ef2e6fc24ea85e70404638', nil)
    req.add_folder_override('docs/**')
    req
  end

  let(:dir) do
    PackageProvider::CachedRepository.cache_dir(request)
  end
  let(:repo_ready) { PackageProvider::CachedRepository::PACKAGE_PART_READY }
  let(:repo_error) { PackageProvider::CachedRepository::ERROR }
  let(:repo_clone) { PackageProvider::CachedRepository::CLONE_LOCK }
  after(:each) do
    repo && repo.destroy
    repo2 && repo2.destroy
  end

  describe '#cached_clone' do
    after(:each) do
      FileUtils.rm_rf(dir)
      FileUtils.rm_rf("#{dir + repo_ready}")
    end

    it 'creates cache' do
      repo.cached_clone(request)

      expect(Dir.exist?(dir)).to be true
      expect(File.exist?("#{dir + repo_ready}")).to be true
      expect(File.exist?("#{dir + repo_clone}")).to be false
    end

    it 'loads from existing cache' do
      repo.cached_clone(request)

      expect(repo).not_to receive(:clone).with(any_args)

      repo.cached_clone(request)
    end

    it 'handles multiple same requests at once' do
      thread_ready = false
      t = Thread.new do
        expect(repo).to receive(:clone).with(any_args) do
          thread_ready = true
          Thread.pass
          sleep 3
        end
        repo.cached_clone(request)
      end

      Thread.pass until thread_ready

      expect { repo2.cached_clone(request) }.to raise_error(
        PackageProvider::CachedRepository::CloneInProgress)
      t.join
    end

    it 'removes .clone_lock file on Exception' do
      expect(repo).to receive(:clone).with(any_args) { fail RuntimeError }

      expect { repo.cached_clone(request) }.to raise_error(
        RuntimeError)

      expect(File.exist?("#{dir + repo_ready}")).to be false
      expect(File.exist?("#{dir + repo_clone}")).to be false
    end

    it 'creates error file on clone exception' do
      expect(repo).to receive(:clone).with(any_args) do
        fail PackageProvider::Repository::CannotCloneRepo
      end

      repo.cached_clone(request)

      expect(File.exist?("#{dir + repo_ready}")).to be true
      expect(File.exist?("#{dir + repo_error}")).to be true

      FileUtils.rm_rf("#{dir + repo_error}")
    end

    it 'creates error file on fetch exception' do
      expect(repo).to receive(:clone).with(any_args) do
        fail PackageProvider::Repository::CannotFetchRepo
      end

      repo.cached_clone(request)

      expect(File.exist?("#{dir + repo_ready}")).to be true
      expect(File.exist?("#{dir + repo_error}")).to be true

      FileUtils.rm_rf("#{dir + repo_error}")
    end
  end
end
