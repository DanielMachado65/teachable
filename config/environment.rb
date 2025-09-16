# frozen_string_literal: true
require "mongo"

Mongo::Logger.logger.level = Logger::WARN

DB = begin
  url = ENV.fetch("MONGO_URL", "mongodb://localhost:27017/sinatra_db")
  Mongo::Client.new(url).database
end

# Índices úteis
DB[:users].indexes.create_one({ id: 1 }, unique: true) rescue nil
DB[:courses].indexes.create_one({ id: 1 }, unique: true) rescue nil
DB[:enrollments].indexes.create_one({ course_id: 1, user_id: 1 }, unique: true) rescue nil
DB[:enrollments].indexes.create_one({ course_id: 1 }) rescue nil
