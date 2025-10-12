# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# MaskList is an ActiveRecord model that represents a list of masks.
# It includes the `AttackResource` module to provide resource management functionality,
# such as file attachments, validations, and relationships with other models like `Project`.
#
# === Callbacks
# - After saving, the `update_complexity_value` method is triggered if the `complexity_value` is blank (i.e., equals 0.0).
#
# === Relationships
# - Belongs to a creator (User).
# - Has attached files.
# - Has associations with multiple projects.
#
# === Scopes
# - This model inherits its scopes and validations from the `AttackResource` module.
#
# === Validations
# - Ensures the presence and uniqueness of the name.
# - Validates attached file type and content.
#
# === Methods
#
# blank_complexity_value
# ------------------------------------------------------------------------------
# Checks if the complexity value is blank (equals 0.0).
#
# @return [Boolean] true if the complexity value is 0.0, false otherwise.
#
# update_complexity_value
# ------------------------------------------------------------------------------
# Updates the `complexity_value` of the MaskList instance by enqueuing a job
# to calculate mask complexity. This method is called if the current complexity
# value is blank (0.0).
#
# @return [void]
# == Schema Information
#
# Table name: mask_lists
#
#  id                                                  :bigint           not null, primary key
#  complexity_value(Total attemptable password values) :decimal(, )      default(0.0)
#  description(Description of the mask list)           :text
#  line_count(Number of lines in the mask list)        :bigint
#  name(Name of the mask list)                         :string(255)      not null, uniquely indexed
#  processed(Has the mask list been processed?)        :boolean          default(FALSE), not null, indexed
#  sensitive(Is the mask list sensitive?)              :boolean          default(FALSE), not null
#  created_at                                          :datetime         not null
#  updated_at                                          :datetime         not null
#  creator_id(The user who created this list)          :bigint           indexed
#
# Indexes
#
#  index_mask_lists_on_creator_id  (creator_id)
#  index_mask_lists_on_name        (name) UNIQUE
#  index_mask_lists_on_processed   (processed)
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#
class MaskList < ApplicationRecord
  include AttackResource

  after_save :update_complexity_value, if: :blank_complexity_value

  def blank_complexity_value
    complexity_value == 0.0
  end

  # Updates the complexity value for the current object.
  # This method checks if the class name of the object is "MaskList".
  # If true, it enqueues a job to calculate the mask complexity.
  # The job is performed asynchronously using ActiveJob.
  #
  # @return [void]
  def update_complexity_value
    CalculateMaskComplexityJob.perform_later(id)
  end
end
