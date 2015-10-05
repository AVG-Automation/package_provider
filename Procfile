package_packer: sidekiq -q package_packer -r ./lib/sidekiq/packer_worker.rb
clone_repository: sidekiq -q clone_repository -r ./lib/sidekiq/repository_worker.rb
web: bundle exec rackup -p $PORT -E $ENV
