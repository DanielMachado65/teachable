# frozen_string_literal: true
class EnrollmentRepo
  def initialize(db: DB) = (@col = db[:enrollments])

  def for_course(course_id)
    @col.find({ course_id: course_id }).to_a
  end

  def upsert_many(course_id, enrollments)
    return if enrollments.nil? || enrollments.empty?
    now = Time.now.utc
    ops = enrollments.map do |e|
      {
        update_one: {
          filter: { course_id: course_id, user_id: e["user_id"] },
          update: {
            "$set" => {
              course_id: course_id,
              user_id: e["user_id"],
              enrolled_at: e["enrolled_at"],
              completed_at: e["completed_at"],
              percent_complete: e["percent_complete"],
              expires_at: e["expires_at"],
              raw: e,
              updated_at: now
            }
          },
          upsert: true
        }
      }
    end
    @col.bulk_write(ops)
    @col.update_one({ course_id: course_id, user_id: :_meta },
                    { "$set" => { course_id: course_id, user_id: :_meta, updated_at: now } },
                    upsert: true)
  end

  def stale?(course_id, ttl_seconds:)
    meta = @col.find({ course_id: course_id, user_id: :_meta }).first
    return true unless meta
    (Time.now.utc - (meta["updated_at"] || Time.at(0))) > ttl_seconds
  end
end
