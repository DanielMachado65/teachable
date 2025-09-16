require_relative "../lib/teachable_client"

RSpec.describe TeachableClient do
  let(:client) { described_class.new(base_url: "https://developers.teachable.com", api_key: "KEY") }

  it "paginates courses until last page" do
    stub_request(:get, %r{/v1/courses.*page=1}).to_return(
      body: { data: [{ "id"=>1, "name"=>"A", "heading"=>"H" }], meta: { page: 1, number_of_pages: 2 } }.to_json
    )
    stub_request(:get, %r{/v1/courses.*page=2}).to_return(
      body: { data: [{ "id"=>2, "name"=>"B", "heading"=>"H2" }], meta: { page: 2, number_of_pages: 2 } }.to_json
    )

    list = client.published_courses
    expect(list.map { |c| c["id"] }).to eq([1, 2])
  end

  it "fetches enrollments for a course" do
    stub_request(:get, "https://developers.teachable.com/v1/courses/1/enrollments")
      .to_return(body: { data: [{ "user" => { "name"=>"Jane", "email"=>"jane@x.com" } }] }.to_json)

    data = client.course_enrollments(1)
    expect(data.first["user"]["email"]).to eq("jane@x.com")
  end
end
