# frozen_string_literal: true
require "oj"

class App < Sinatra::Base
  # JSON
  get "/api/reports/published_courses" do
    content_type :json

    courses = teachable_service.published_courses_cached.map do |c|
      { id: c["id"], name: c["name"], heading: c["heading"] }
    end

    enriched = courses.map do |c|
      enrolls  = teachable_service.enrollments_with_users_cached(c[:id])
      students = enrolls.map do |e|
        u = e["user"] || {}
        { name: u["name"], email: u["email"] }.compact
      end
      c.merge(students: students)
    end

    Oj.dump({ data: enriched }, mode: :compat)
  end

  # HTML
  get "/reports/published_courses" do
    erb :courses
  end
end
