class Task < ApplicationRecord
  belongs_to :user

  enum :status, {
    pending: 0,
    in_progress: 1,
    completed: 2,
    cancelled: 3
  }

  enum :priority, {
    low: 0,
    medium: 1,
    high: 2,
    urgent: 3
  }

  validates :title, presence: true, length: { minimum: 3, maximum: 200 }
  validates :description, length: { maximum: 5000 }
  validates :status, presence: true
  validates :priority, presence: true

  scope :active, -> { where.not(status: %i[ completed cancelled ]) }

  scope :overdue, -> { active.where("due_date < ?", Time.current) }

  scope :due_soon, -> { active.where(due_date: Time.current..3.days.from_now) }

  scope :by_priority, -> { order(priority: :desc) }
end
