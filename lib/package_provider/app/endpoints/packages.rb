require 'package_provider/app/endpoints/base'
require 'package_provider/request_parser/parser'
require 'package_provider/cached_package'
require 'package_provider/workers/packer_worker'

module PackageProvider
  class App
    module Endpoints
      # handles all endpoints related to packages
      class Packages < Base
        post '/download' do
          package_request, error_msg = parse_request(request)
          halt 400, { message: error_msg }.to_json unless package_request

          package_request.normalize!

          unless PackageProvider::CachedPackage.package_ready?(package_request)
            PackageProvider::PackerWorker.perform_async(package_request.to_json)
          end

          halt 202, { package_hash: "#{package_request.fingerprint}" }.to_json
        end

        get '/download/:package_hash' do
          info = PackageProvider::CachedPackage.errors(params['package_hash'])
          halt 404, info.to_json if info

          result = PackageProvider::CachedPackage.from_cache(
            params['package_hash'])
          return send_file(result, type: 'application/zip') if result

          halt 202, { message: 'Package is being prepared' }.to_json
        end

        def parse_request(request)
          if request.content_type == 'application/json'
            return [
              PackageProvider::Parser.new.parse_json(request.body.read), nil]
          elsif request.content_type == 'text/plain'
            return [PackageProvider::Parser.new.parse(request.body.read), nil]
          end
        rescue JSON::ParserError => err
          [nil, "Unable to parse JSON: #{err}"]
        rescue => err
          [nil, "Unable to process request: #{err}"]
        end
      end
    end
  end
end
