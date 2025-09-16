require_relative './app'

if ENV['RACK_ENV'] == 'development'
  require 'rack/reloader'
  use Rack::Reloader, 0
end

run App
