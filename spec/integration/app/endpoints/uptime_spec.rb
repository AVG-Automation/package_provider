require 'rack/test'

describe 'Application API uptime' do
  include Rack::Test::Methods

  def app
    PackageProvider::App.new
  end

  describe 'uptime API' do
    let(:headers_json) do
      {
        'HTTP_ACCEPT' => 'application/json',
        'CONTENT_TYPE' => 'application/json'
      }
    end
    let(:prefix) { PackageProvider.config.base_url }

    it 'responds to uptime' do
      allow(Sidekiq::Queue).to receive_message_chain(:new, :size) { 0 }
      allow(Sidekiq::Queue).to receive_message_chain(:new, :latency) { 0 }

      response = get "#{prefix}/uptime", {}, headers_json

      expect(response.body).to eq(
        "Up from #{PackageProvider.start_time}!\n" \
        "Packer queue-status size: 0 latency: 0\n" \
        'Repository queue-status size: 0 latency: 0')
    end
  end
end
