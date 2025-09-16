require 'sinatra'
require 'mongo'
require 'json'
require 'pry'

# Establish MongoDB connection
MONGO_URL = ENV.fetch('MONGO_URL', 'mongodb://localhost:27017/mydb')
DB = Mongo::Client.new(MONGO_URL)

# Define the Sinatra application
class App < Sinatra::Base
  get '/' do
    'Sinatra MongoDB API'
  end

  get '/items' do
    content_type :json
    docs = DB[:items].find.map { |d| d.merge('_id' => d['_id'].to_s) }
    docs.to_json
  end

  post '/items' do
    content_type :json
    body = request.body.read
    halt 400, { error: 'Empty body' }.to_json if body.strip.empty?

    begin
      data = JSON.parse(body)
    rescue JSON::ParserError
      halt 400, { error: 'Invalid JSON' }.to_json
    end

    halt 400, { error: 'Expected an array of objects' }.to_json unless data.is_a?(Array)

    result = DB[:items].insert_many(data)
    status 201
    { ids: result.inserted_ids.map(&:to_s) }.to_json
  end
end

App.run! if __FILE__ == $0
