require 'package_provider/app/endpoints/base'
require 'sidekiq/api'

module PackageProvider
  class App
    module Endpoints
      # handles uptime endpoint
      class Uptime < Base
        get '/uptime' do
          "Up from #{PackageProvider.start_time}!" \
          "\n" \
          'Packer queue-status ' \
          "size: #{Sidekiq::Queue.new('package_packer').size}" \
          " latency: #{Sidekiq::Queue.new('package_packer').latency}" \
          "\n" \
          'Repository queue-status ' \
          "size: #{Sidekiq::Queue.new('clone_repository').size}" \
          " latency: #{Sidekiq::Queue.new('clone_repository').latency}"
        end
      end
    end
  end
end
