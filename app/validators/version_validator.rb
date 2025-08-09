# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "sem_version" # Ensure SemVersion is required

# The VersionValidator class performs custom validation on the `version` attribute of a model.
#
# It ensures that the `version` attribute is not nil or empty on the record being validated.
# Additionally, it checks if the value of the `version` attribute conforms to a valid semantic
# version format using the `SemVersion.valid?` method.
#
# If the `version` attribute is missing or invalid, relevant error messages are appended to
# the record's errors collection.
#
# To use this validator, include it in the model's validations and define the `version` attribute appropriately.
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
