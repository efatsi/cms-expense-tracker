class ExpenseCategory < ApplicationRecord
  has_many :expenses

  scope :active, -> { where(active: true) }

  validates :name, presence: true
end
