# frozen_string_literal: true
require_relative "../repository/user_repo"
require_relative "../repository/course_repo"
require_relative "../repository/enrollment_repo"

class TeachableService
  def initialize(client:, user_repo: UserRepo.new, course_repo: CourseRepo.new, enrollment_repo: EnrollmentRepo.new)
    @client         = client
    @user_repo      = user_repo
    @course_repo    = course_repo
    @enrollment_repo= enrollment_repo
    @ttl            = ENV.fetch("CACHE_TTL_SECONDS", "900").to_i
  end

  def published_courses_cached
    if @course_repo.all_published.any? && !@course_repo.stale?(ttl_seconds: @ttl)
      return @course_repo.all_published
    end

    api_courses = @client.published_courses
    api_courses.each { |c| c["published"] = true if c["published"].nil? }
    @course_repo.upsert_many(api_courses)
    @course_repo.all_published
  end

  def enrollments_with_users_cached(course_id)
    if @enrollment_repo.for_course(course_id).any? && !@enrollment_repo.stale?(course_id, ttl_seconds: @ttl)
      enrolls = @enrollment_repo.for_course(course_id)
    else
      enrolls = []
      page = 1
      loop do
        chunk = @client.enrollments(course_id, page: page)
        arr   = chunk[:enrollments]
        enrolls.concat(arr)
        meta  = chunk[:meta]
        break if arr.empty? || meta["page"].to_i >= meta["number_of_pages"].to_i
        page += 1
      end
      @enrollment_repo.upsert_many(course_id, enrolls)
      enrolls = @enrollment_repo.for_course(course_id)
    end

    user_ids = enrolls.map { |e| e["user_id"] }.compact.uniq
    users_map = preload_users(user_ids) # { id => user_hash }

    enrolls.map do |e|
      u = users_map[e["user_id"]]
      e.merge("user" => u&.slice("id", "name", "email"))
    end
  end

  def enrollments_only_cached(course_id)
    if @enrollment_repo.for_course(course_id).any? && !@enrollment_repo.stale?(course_id, ttl_seconds: @ttl)
      return @enrollment_repo.for_course(course_id)
    end

    enrolls = []
    page = 1
    loop do
      chunk = @client.enrollments(course_id, page: page)
      arr   = chunk[:enrollments]
      enrolls.concat(arr)
      meta  = chunk[:meta]
      break if arr.empty? || meta["page"].to_i >= meta["number_of_pages"].to_i
      page += 1
    end

    @enrollment_repo.upsert_many(course_id, enrolls)
    @enrollment_repo.for_course(course_id)
  end

  def preload_users(ids)
    out, missing = {}, []
    ids.each do |id|
      if !@user_repo.stale?(id, ttl_seconds: @ttl)
        if (cached = @user_repo.find_by_id(id))
          out[id] = cached
          next
        end
      end
      missing << id
    end
    return out if missing.empty?

    fetched = @client.users_by_ids(missing)
    fetched.each do |uid, user_hash|
      stored = @user_repo.upsert(user_hash) rescue user_hash
      out[uid] = stored || user_hash
    end
    out
  end

  private

  def preload_users(ids)
    out, missing = {}, []

    ids.each do |id|
      if !@user_repo.stale?(id, ttl_seconds: @ttl)
        if (cached = @user_repo.find_by_id(id))
          out[id] = cached
          next
        end
      end
      missing << id
    end

    return out if missing.empty?

    fetched = @client.users_by_ids(missing)
    fetched.each do |uid, user_hash|
      stored = @user_repo.upsert(user_hash) rescue user_hash
      out[uid] = stored || user_hash
    end

    out
  end
end
