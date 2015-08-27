# required include pp because of superclass mismatch issue
# https://github.com/defunkt/fakefs/issues/99
require 'pp'
require 'fakefs/safe'

describe PackageProvider::Repository do
  PackageProvider::Repository.temp_prefix = "pp_tests_#{rand(1000)}"

  let(:repo) do
    status = double(:status)
    expect(status).to receive(:success?).twice.and_return(true)
    expect(Open3).to(
      receive(:capture3)
      .with({ 'ENV' => PackageProvider.env }, /.*init_repo.sh/, any_args)
      .once
      .and_return(['', '', status])
    )

    PackageProvider::Repository.new(
      'https://github.com/AVGTechnologies/package_provider')
  end

  before(:all) do
    FakeFS.activate!
  end

  after(:all) do
    FakeFS.deactivate!
  end

  describe '#initialize' do
    it 'constructor creates folder' do
      expect(Dir.exist?(repo.repo_root)).to be true
    end

    it 'raise exception when local folder to clone does not exists' do
      expect do
        PackageProvider::Repository.new(
          'https://github.com/AVGTechnologies/package_provider',
          '/path_not_exist'
        )
      end.to raise_error(PackageProvider::Repository::InvalidRepoPath)
    end
  end

  describe '#clone' do
    let(:treeish) { '4642e6cbebcaa4a7bf94703da1d8ab827b801b34' }
    let(:dest_dir) { '/tt' }
    let(:paths) { ['README.md'] }

    it 'calls 3x Open3::capture' do
      status = double(:status)
      expect(status).to receive(:success?).twice.and_return(true)

      expect(repo).to receive(:fetch).with(treeish).once

      FileUtils.mkdir_p(File.join(repo.repo_root, '.git', 'info'))

      expect(Open3).to(
        receive(:capture3)
        .with({ 'ENV' => PackageProvider.env }, /.*clone.sh/, any_args)
        .once.and_return(['', '', status])
      )

      repo.clone(dest_dir, treeish, paths, false)
      file_path = File.join(repo.repo_root, '.git', 'info', 'sparse-checkout')
      expect(File.read(file_path)).to eq paths.join("\n") + "\n"
    end

    it 'raise exception when destination folder exists' do
      dir_path = Dir.mktmpdir(PackageProvider::Repository.temp_prefix)

      expect do
        repo.clone(dir_path, nil, [], false)
      end.to raise_error(PackageProvider::Repository::InvalidRepoPath)

      FileUtils.rm_rf(dir_path)
    end
  end

  describe '#fetch' do
    it 'calls 2x Open3::capture3' do
      status = double(:status)
      expect(status).to receive(:success?).twice.and_return(true)

      expect(Open3).to(
        receive(:capture3)
        .with({}, 'git', any_args)
        .once
        .and_return(['', '', status])
      )

      repo.fetch(nil)
    end
  end

  describe '#destroy' do
    it 'cleans up repo_root' do
      expect(Dir.exist?(repo.repo_root)).to be true
      repo.destroy
      expect(Dir.exist?(repo.repo_root)).to be false
    end
  end
end
