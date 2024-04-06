# frozen_string_literal: true

class VersionValidator < ActiveModel::Validator
  def validate(record)
    if record.nil? || record.version.nil? || record.version.empty?
      record.errors.add(:version, "Version can't be blank")
      return
    end
    return if record.present? && SemVersion.valid?(record.version)

      record.errors.add(:version, "Invalid version format")
  end
end
