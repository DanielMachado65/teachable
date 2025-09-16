# frozen_string_literal: true
require_relative "../repository/user_repo"
require_relative "../repository/course_repo"
require_relative "../repository/enrollment_repo"

class TeachableService
  DEFAULT_BATCH = 500

  def initialize(
    client:,
    user_repo:        UserRepo.new,
    course_repo:      CourseRepo.new,
    enrollment_repo:  EnrollmentRepo.new,
    ttl_seconds:      ENV.fetch("CACHE_TTL_SECONDS", "900").to_i,
    batch_size:       DEFAULT_BATCH
  )
    @client          = client
    @user_repo       = user_repo
    @course_repo     = course_repo
    @enrollment_repo = enrollment_repo
    @ttl             = ttl_seconds
    @batch_size      = batch_size
  end

  def published_courses_cached(force_refresh: false)
    if !force_refresh && @course_repo.all_published.any? && !@course_repo.stale?(ttl_seconds: @ttl)
      return @course_repo.all_published
    end

    api_courses = Array(@client.published_courses)
    api_courses.each { |c| c["published"] = !!c.fetch("published", true) }

    upsert_in_batches(@course_repo, api_courses)
    @course_repo.all_published
  end

  def enrollments_with_users_cached(course_id, force_refresh: false)
    enrolls = enrollments_only_cached(course_id, force_refresh: force_refresh)

    user_ids  = enrolls.map { |e| e["user_id"] }.compact.uniq
    users_map = preload_users(user_ids)

    enrolls.map do |e|
      u = users_map[e["user_id"]]
      e.merge("user" => u&.slice("id", "name", "email"))
    end
  end

  def enrollments_only_cached(course_id, force_refresh: false)
    if !force_refresh && @enrollment_repo.for_course(course_id).any? &&
        !@enrollment_repo.stale?(course_id, ttl_seconds: @ttl)
      return @enrollment_repo.for_course(course_id)
    end

    buffer = []
    enum = enumerator_for_enrollments(course_id)

    enum.each do |enr|
      buffer << enr
      if buffer.size >= @batch_size
        @enrollment_repo.upsert_many(course_id, buffer)
        buffer.clear
      end
    end
    @enrollment_repo.upsert_many(course_id, buffer) if buffer.any?

    @enrollment_repo.for_course(course_id)
  end

  def preload_users(ids)
    ids = Array(ids).compact.uniq
    return {} if ids.empty?

    out     = {}
    missing = []

    ids.each do |id|
      fresh = !@user_repo.stale?(id, ttl_seconds: @ttl)
      cached = @user_repo.find_by_id(id)
      if fresh && cached
        out[id] = cached
      else
        missing << id
      end
    end

    return out if missing.empty?

    fetched = @client.users_by_ids(missing)
    if @user_repo.respond_to?(:upsert_many)
      @user_repo.upsert_many(fetched.values)
      fetched.each { |uid, user_hash| out[uid] = user_hash }
    else
      fetched.each do |uid, user_hash|
        stored = @user_repo.upsert(user_hash) rescue user_hash
        out[uid] = stored || user_hash
      end
    end

    out
  end

  private

  def enumerator_for_enrollments(course_id)
    if @client.respond_to?(:enrollments_enum)
      @client.enrollments_enum(course_id) # Enumerator
    else
      Enumerator.new do |y|
        page = 1
        loop do
          chunk = @client.enrollments(course_id, page: page)
          arr   = Array(chunk[:enrollments])
          arr.each { |e| y << e }
          meta  = chunk[:meta] || {}
          break if arr.empty? || meta["page"].to_i >= meta["number_of_pages"].to_i
          page += 1
        end
      end
    end
  end

  def upsert_in_batches(repo, rows)
    return if rows.empty?
    if repo.respond_to?(:upsert_many)
      rows.each_slice(@batch_size) { |slice| repo.upsert_many(slice) }
    else
      rows.each { |r| repo.upsert(r) }
    end
  end
end
