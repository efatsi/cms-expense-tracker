class Expense < ApplicationRecord
  belongs_to :receipt
  belongs_to :expense_category

  validates :description, :amount, presence: true
  validates :amount, numericality: { greater_than: 0 }
end
