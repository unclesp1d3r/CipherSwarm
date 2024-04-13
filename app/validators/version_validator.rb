# frozen_string_literal: true

class VersionValidator < ActiveModel::Validator
  # Validates the version attribute of a record.
  #
  # If the record is nil, or the version attribute is nil or empty, an error is added to the record.
  # If the version attribute is present, it is checked against the SemVersion.valid? method.
  # If the version is not in a valid format, an error is added to the record.
  #
  # @param record [Object] The record to be validated.
  # @return [void]
  def validate(record)
    if record.nil? || record.version.nil? || record.version.empty?
      record.errors.add(:version, "Version can't be blank")
      return
    end
    return if record.present? && SemVersion.valid?(record.version)

    record.errors.add(:version, "Invalid version format")
  end
end
