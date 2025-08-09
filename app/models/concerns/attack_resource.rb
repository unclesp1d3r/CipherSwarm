# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

include ActiveSupport::NumberHelper

# Module: AttackResource
#
# A concern that provides functionality for managing and validating attack resources
# with Active Storage attachments and relationships to associated models like Projects and User.
# It includes support for validations, callbacks, scopes, and delegated methods.
#
# Includes:
# - Active Storage attachment for files.
# - Association to projects with many-to-many relationship.
# - Optional association to a creator object (User model).
# - Validation for attributes such as name, file, line_count, and sensitive flag.
# - Scopes for filtering sensitive and shared resources.
# - Callbacks for updating line count post commit.
# - Support for broadcasting updates unless the environment is a test.
# - Delegation for checking file attachment status with a prefix.
module AttackResource
  extend ActiveSupport::Concern
  included do
    has_one_attached :file
    has_and_belongs_to_many :projects
    belongs_to :creator, class_name: "User", optional: true
    validates :name, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 255 }
    validates :file, attached: true, content_type: %i[text/plain application/octet-stream]
    validates :line_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
    has_many :attacks, dependent: :destroy
    validates :projects, presence: { message: "must be selected for sensitive lists" }, if: -> { sensitive? }
    validates :sensitive, inclusion: { in: [true, false] }, allow_nil: false

    scope :sensitive, -> { where(sensitive: true) }
    scope :shared, -> { where(sensitive: false) }

    default_scope { order(:created_at) }

    after_commit :update_line_count, if: :file_attached?

    broadcasts_refreshes unless Rails.env.test?

    delegate :attached?, to: :file, prefix: true

    # Calculates the complexity of the attack resource.
    #
    # @return [BigDecimal] Returns the complexity value field if the class name is "MaskList".
    #                              Otherwise, returns the line count as a BigDecimal.
    def complexity
      return complexity_value if self.class.name == "MaskList"
      line_count.to_d
    end

    # Returns a human-readable string representation of the complexity value.
    # The complexity value is formatted using SI prefixes.
    #
    # @return [String] the human-readable complexity value
    def complexity_string
      number_to_human(complexity, prefix: :si)
    end

    # Updates the line count for the current resource.
    # If the environment is test, it performs the job immediately.
    # Otherwise, it enqueues the job to be performed later.
    #
    # @return [void]
    def update_line_count
      if Rails.env.test?
        CountFileLinesJob.perform_now(id, self.class.name)
        return
      end
      CountFileLinesJob.perform_later(id, self.class.name)
    end
  end
end
