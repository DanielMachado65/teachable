# frozen_string_literal: true
class TeachableClient
  include HTTParty
  DEFAULT_PER = 50

  def initialize(base_url:, api_key:)
    @base_url = base_url
    @api_key  = api_key
  end

  def published_courses
    page = 1
    results = []
    loop do
      res = get_json("/v1/courses", { published: true, per: DEFAULT_PER, page: page })
      data = res.fetch("courses", [])
      results.concat(data)
      meta = res["meta"] || {}
      break if data.empty? || meta["page"].to_i >= meta["number_of_pages"].to_i
      page += 1
    end
    results
  end

  def enrollments_with_users(course_id)
    all = []
    page = 1
    loop do
      chunk = enrollments(course_id, page: page)
      arr   = chunk[:enrollments]
      all.concat(arr)
      meta  = chunk[:meta]
      break if arr.empty? || meta["page"].to_i >= meta["number_of_pages"].to_i
      page += 1
    end

    user_ids = all.map { |e| e["user_id"] }.compact.uniq
    users_map = users_by_ids(user_ids)

    all.map do |e|
      u = users_map[e["user_id"]]
      e.merge("user" => u&.slice("id","name","email"))
    end
  end

  def users_by_ids(ids, max_threads: 5)
    ids = ids.compact.uniq
    return {} if ids.empty?

    queue = Queue.new
    ids.each { |id| queue << id }

    mutex = Mutex.new
    out = {}

    workers = Array.new([max_threads, ids.size].min) do
      Thread.new do
        until queue.empty?
          id = nil
          begin
            id = queue.pop(true)
          rescue ThreadError
            break
          end
          begin
            user = user_by_id(id)
            mutex.synchronize { out[id] = user } if user
          rescue => e
            puts "Error fetching user #{id}: #{e.message}"
          end
        end
      end
    end
    workers.each(&:join)
    out
  end

  def user_by_id(id)
    get_json("/v1/users/#{id}")
  end

  def users_scan_until(ids, per: 200)
    wanted = ids.compact.uniq.to_h { |i| [i, true] }
    out = {}
    page = 1
    loop do
      res = get_json("/v1/users", { per: per, page: page })
      users = res["users"] || res["data"] || []
      users.each do |u|
        uid = u["id"] || u["user_id"]
        next unless wanted.key?(uid)
        out[uid] = u
      end
      break if out.size >= wanted.size
      meta = res["meta"] || {}
      break if users.empty? || meta["page"].to_i >= meta["number_of_pages"].to_i
      page += 1
    end
    out
  end

  private

  def get_json(path, params = {})
    url  = File.join(@base_url, path)
    resp = self.class.get(url, query: params, headers: headers)
    raise "HTTP error: #{resp.code}" unless resp.success?
    Oj.load(resp.body)
  end

  def headers
    {
      "Accept" => "application/json",
      "apiKey" => @api_key
    }
  end
end
