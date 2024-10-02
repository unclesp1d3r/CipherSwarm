# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

include ActiveSupport::NumberHelper

# The AttackResource module provides functionality for managing attack resources within the application.
# It includes ActiveSupport::Concern to extend the module's capabilities.
#
# Associations:
# - has_one_attached :file
# - has_and_belongs_to_many :projects
# - has_many :attacks, dependent: :destroy
#
# Validations:
# - Validates presence, uniqueness, and length of :name
# - Validates attachment and content type of :file
# - Validates numericality of :line_count
# - Validates presence of :projects if the resource is sensitive
# - Validates inclusion of :sensitive in [true, false]
#
# Scopes:
# - sensitive: Returns resources marked as sensitive
# - shared: Returns resources not marked as sensitive
#
# Default Scope:
# - Orders resources by :created_at
#
# Callbacks:
# - after_save :update_line_count, if: :file_attached?
# - after_create :update_complexity_value, if: self.class.name == "MaskList"
#
# Broadcasting:
# - broadcasts_refreshes unless Rails.env.test?
#
# Delegations:
# - Delegates :attached? to :file with prefix :file
#
# Instance Methods:
# - complexity: Calculates and returns the complexity of the attack resource
# - complexity_string: Returns a human-readable string representation of the complexity value
# - update_complexity_value: Updates the complexity value for the current object
# - update_line_count: Updates the line count for the current resource
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
