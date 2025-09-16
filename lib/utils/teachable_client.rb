# frozen_string_literal: true
require "uri"
require 'pry'

class TeachableClient
  include HTTParty

  DEFAULT_PER      = 50
  DEFAULT_TIMEOUTS = { read: 10, open: 5 } # segundos
  MAX_RETRIES      = 5
  BACKOFF_BASE     = 0.5 # segundos

  def initialize(base_url:, api_key:, per: DEFAULT_PER, timeouts: {}, cache: nil, logger: nil)
    @base_url = base_url.sub(%r{/\z}, "")
    @api_key  = api_key
    @per      = per
    @cache    = cache
    @logger   = logger

    self.class.default_timeout timeouts.fetch(:read,  DEFAULT_TIMEOUTS[:read])
    self.class.open_timeout     timeouts.fetch(:open,  DEFAULT_TIMEOUTS[:open])
  end

  def published_courses
    paginate_collect("/v1/courses", { published: true, per: @per }, data_keys: ['courses'])
  end

  def enrollments_enum(course_id)
    paginate_enum("/v1/courses/#{course_id}/enrollments",
                  { per: @per },
                  data_keys: ['enrollments'])
  end

  def enrollments_with_users(course_id)
    enrollments = enrollments_enum(course_id).to_a

    user_ids = enrollments.map { |e| e["user_id"] }
                      .compact
                      .reject { |id| id == :_meta }        # ignora doc meta
                      .map { |id| id.is_a?(String) && id =~ /^\d+$/ ? id.to_i : id }
                      .select { |id| id.is_a?(Integer) }
                      .uniq
    users_map = users_by_ids(user_ids)

    enrollments.map do |e|
      u = users_map[e["user_id"]]
      e.merge("user" => u&.slice("id", "name", "email"))
    end
  end

  def users_by_ids(ids, per: 200)
    idsx = sanitize_ids(ids)
    return {} if idsx.empty?
    users_scan_until(idsx, per: per)
  end

  def users_scan_until(ids, per: 200)
    idsx   = sanitize_ids(ids)
    return {} if idsx.empty?

    wanted = idsx.each_with_object({}) { |i, h| h[i] = true }
    out    = {}

    paginate_enum("/v1/users", { per: per }, data_keys: %w[users]).each do |u|
      uid = u["id"] || u["user_id"]
      next unless wanted.key?(uid)
      out[uid] = u
      break if out.size >= wanted.size
    end

    out
  end

  private


  def sanitize_ids(ids)
    Array(ids)
      .compact
      .reject { |i| i == :_meta || i == "_meta" }   # corta meta
      .map { |i| i.is_a?(String) && i =~ /\A\d+\z/ ? i.to_i : i }
      .select { |i| i.is_a?(Integer) }
      .uniq
  end

  def paginate_enum(path, params = {}, data_keys: %w[data])
    Enumerator.new do |y|
      page = 1
      loop do
        res  = get_json(path, params.merge(page: page))
        data = first_present_array(res, data_keys)
        data.each { |row| y << row }

        meta = res["meta"] || {}
        break if data.empty? || meta["page"].to_i >= meta["number_of_pages"].to_i
        page += 1
      end
    end
  end

  def paginate_collect(path, params = {}, data_keys: %w[data])
    paginate_enum(path, params, data_keys: data_keys).to_a
  end

  def first_present_array(res, keys)
    keys.each do |k|
      v = res[k]
      return v if v.is_a?(Array)
    end
    []
  end

  def get_json(path, params = {})
    url = File.join(@base_url, path)

    cache_key = nil
    if @cache
      q = URI.encode_www_form(params.sort_by { |k, _| k.to_s })
      cache_key = "teachable:#{path}?#{q}"
      cached = @cache.read(cache_key)
      return cached if cached
    end

    resp = with_retries("#{path} #{params.inspect}") do
      self.class.get(url, query: params, headers: headers)
    end

    raise "HTTP error: #{resp.code} body=#{truncate(resp.body)}" unless resp.success?

    parsed = Oj.load(resp.body)
    @cache&.write(cache_key, parsed, expires_in: 5.minutes) if @cache
    parsed
  end

  def headers
    {
      "Accept" => "application/json",
      "apiKey" => @api_key
    }
  end

  def with_retries(context)
    tries = 0
    begin
      tries += 1
      resp = yield

      if resp.code.to_i == 429
        wait = (resp.headers["retry-after"] || BACKOFF_BASE * (2 ** (tries - 1))).to_f
        log(:warn, "429 on #{context}, retry in #{wait}s (attempt #{tries}/#{MAX_RETRIES})")
        sleep(wait)
        raise "retry-429"
      end

      if resp.code.to_i >= 500
        raise "retry-5xx"
      end

      resp
    rescue => e
      raise e if tries >= MAX_RETRIES
      wait = BACKOFF_BASE * (2 ** (tries - 1))
      log(:warn, "Retry #{tries}/#{MAX_RETRIES} for #{context} after error: #{e.class}: #{e.message} (sleep #{wait}s)")
      sleep(wait)
      retry
    end
  end

  def log(level, msg)
    @logger&.public_send(level, "[TeachableClient] #{msg}")
  end

  def truncate(str, n = 300)
    s = str.to_s
    s.length > n ? "#{s[0, n]}…" : s
  end
end
