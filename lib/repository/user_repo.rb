# frozen_string_literal: true
class UserRepo
  def initialize(db: DB) = (@col = db[:users])

  def find_by_id(id)
    @col.find({ id: id }).first&.dup
  end

  def upsert(user_hash)
    id = user_hash["id"] || user_hash[:id]
    raise ArgumentError, "user must have id" unless id

    doc = {
      id:    id,
      name:  user_hash["name"]  || user_hash[:name],
      email: user_hash["email"] || user_hash[:email],
      raw:   user_hash,
      updated_at: Time.now.utc
    }.compact

    @col.update_one({ id: id }, { "$set" => doc }, upsert: true)
    find_by_id(id)
  end

  def stale?(id, ttl_seconds:)
    u = find_by_id(id)
    return true unless u
    (Time.now.utc - (u["updated_at"] || Time.at(0))) > ttl_seconds
  end
end
