# frozen_string_literal: true
require "sinatra/base"
require "dotenv/load"
require "httparty"
require "json"
require "oj"

require_relative "config/environment"
require_relative "lib/utils/teachable_client"
require_relative "lib/repository/course_repo"
require_relative "lib/repository/enrollment_repo"
require_relative "lib/repository/user_repo"
require_relative "lib/service/teachable_service"

class App < Sinatra::Base
  set :bind, "0.0.0.0"

  helpers do
    def teachable_client
      @teachable_client ||= TeachableClient.new(
        base_url: ENV.fetch("TEACHABLE_API_BASE", "https://developers.teachable.com"),
        api_key:  ENV.fetch("TEACHABLE_API_KEY")
      )
    end

    def teachable_service
      @teachable_service ||= TeachableService.new(client: teachable_client)
    end
  end

  get "/" do
    "Sinatra Teachable API (cache Mongo: courses, enrollments, users)"
  end
end

require_relative "routes/reports"
