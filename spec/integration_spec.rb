require "rack/test"
require_relative "../app"

RSpec.describe "Reports integration", type: :request do
  include Rack::Test::Methods
  def app() App end

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("TEACHABLE_API_BASE").and_return("https://developers.teachable.com")
    allow(ENV).to receive(:[]).with("TEACHABLE_API_KEY").and_return("KEY")
  end

  it "returns published courses with students" do
    stub_request(:get, %r{/v1/courses}).to_return(
      body: { data: [{ "id"=>1, "name"=>"Course 1", "heading"=>"H" }], meta: { page: 1, number_of_pages: 1 } }.to_json
    )
    stub_request(:get, %r{/v1/courses/1/enrollments}).to_return(
      body: { data: [{ "user" => { "name"=>"John", "email"=>"john@x.com" } }] }.to_json
    )

    get "/api/reports/published_courses"
    expect(last_response.status).to eq(200)
    json = JSON.parse(last_response.body)
    expect(json["data"].first["students"].first["email"]).to eq("john@x.com")
  end
end
