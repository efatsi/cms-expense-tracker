class Charge < ApplicationRecord
  belongs_to :payment_method
  belongs_to :receipt, optional: true

  scope :unmatched, -> { where(receipt: nil) }

  validates :transaction_date, :amount, :description, presence: true

  def suggested_receipts
    return Receipt.none unless transaction_date && amount

    date_range = (transaction_date - 3.days)..(transaction_date + 3.days)
    Receipt.joins(:expenses)
           .where(payment_method: payment_method, expense_date: date_range)
           .group("receipts.id")
           .having("SUM(expenses.amount) BETWEEN ? AND ?", amount * 0.99, amount * 1.01)
  end
end
