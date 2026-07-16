class Charge < ApplicationRecord
  belongs_to :payment_method
  has_many :charge_receipts, dependent: :destroy
  has_many :receipts, through: :charge_receipts
  has_many :charge_expenses, dependent: :destroy

  scope :unmatched, -> { where(matched_at: nil) }

  validates :transaction_date, :amount, :description, presence: true

  def nearby_receipts
    return Receipt.none unless transaction_date

    date_range = (transaction_date - 3.days)..(transaction_date + 3.days)
    Receipt.where(expense_date: date_range, payment_method: payment_method).where.not(status: :matched).order(:expense_date)
  end

  def accounted_total
    receipts.joins(:expenses).sum("expenses.amount")
  end
end
