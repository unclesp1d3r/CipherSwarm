# frozen_string_literal: true

module AttackResource
  extend ActiveSupport::Concern
  included do
    has_one_attached :file
    has_and_belongs_to_many :projects
    validates :name, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 255 }
    validates :file, attached: true, content_type: %i[text/plain application/octet-stream]
    validates :line_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
    has_many :attacks, dependent: :destroy
    validates :projects, presence: { message: "must be selected for sensitive lists" }, if: -> { sensitive? }
    validates :sensitive, inclusion: { in: [true, false] }, allow_nil: false

    scope :sensitive, -> { where(sensitive: true) }
    scope :shared, -> { where(sensitive: false) }

    after_save :update_line_count, if: :file_attached?
    broadcasts_refreshes unless Rails.env.test?

    delegate :attached?, to: :file, prefix: true

    def update_line_count
      if Rails.env.test?
        CountFileLinesJob.perform_now(id, self.class.name)
        return
      end
      CountFileLinesJob.perform_later(id, self.class.name)
    end
  end
end
