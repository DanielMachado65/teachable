# frozen_string_literal: true
module Serializers
  module_function

  def course_summary(course)
    {
      id:      course["id"],
      name:    course["name"],
      heading: course["heading"]
    }
  end

  def student_from_enrollment(enrollment)
    u = enrollment["user_id"] || enrollment["student"] || {}
    {
      name:  u["name"]  || u["full_name"] || enrollment["user_name"],
      email: u["email"] || enrollment["user_email"]
    }.compact
  end
end
