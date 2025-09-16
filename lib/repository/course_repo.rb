# frozen_string_literal: true
class CourseRepo
  def initialize(db: DB) = (@col = db[:courses])

  def all_published
    @col.find({ published: true }).to_a
  end

  def upsert_many(courses)
    return if courses.nil? || courses.empty?
    ops = courses.map do |c|
      {
        update_one: {
          filter: { id: c["id"] },
          update: {
            "$set" => {
              id: c["id"],
              name: c["name"],
              heading: c["heading"],
              published: !!c["published"],
              raw: c,
              updated_at: Time.now.utc
            }
          },
          upsert: true
        }
      }
    end
    @col.bulk_write(ops)
  end

  def stale?(ttl_seconds:)
    doc = @col.find.sort(updated_at: -1).first
    return true unless doc
    (Time.now.utc - (doc["updated_at"] || Time.at(0))) > ttl_seconds
  end
end
