source 'https://rubygems.org'

ruby '2.2.2'

gem 'activesupport',    '~> 4.2'
gem 'sentry-raven',     '~> 0.14'
gem 'metriks',          '~> 0.9'

gem 'settingslogic',    '~> 2.0'
gem 'multi_json',       '~> 1.0'

gem 'rack'
gem 'rack-contrib'
# see https://github.com/resque/resque/issues/934
gem 'sinatra',          '~> 1.4', require: 'sinatra/base'
gem 'sinatra-contrib',  '~> 1.4'
gem 'rubyzip',          '~> 1.1'

gem 'connection_pool',  '~> 2.2'
gem 'sidekiq',          '~> 3.5'
gem 'unicorn',          '~> 4.9'

group :test, :development do
  gem 'rspec'
  gem 'rack-test'
  gem 'fakefs'
  gem 'rubocop'
  gem 'codeclimate-test-reporter', require: nil
  gem 'pry'
  gem 'pry-doc'
end
