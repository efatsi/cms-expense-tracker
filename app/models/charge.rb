class Charge < ApplicationRecord
  belongs_to :payment_method
  has_many :charge_receipts, dependent: :destroy
  has_many :receipts, through: :charge_receipts
  has_many :charge_expenses, dependent: :destroy

  scope :unmatched, -> { where(matched_at: nil) }

  validates :transaction_date, :amount, :description, presence: true

  def nearby_receipts
    return Receipt.none unless transaction_date

    date_range = (transaction_date - 6.days)..(transaction_date + 1.day)
    expense_totals_sql = Expense.select("receipt_id, SUM(amount) AS total").group("receipt_id").to_sql
    associated_ids = receipts.pluck(:id)

    scope = Receipt.where(expense_date: date_range, payment_method: payment_method)
                   .joins("INNER JOIN (#{expense_totals_sql}) expense_totals ON expense_totals.receipt_id = receipts.id")

    if associated_ids.any?
      scope.where("receipts.charges_total < expense_totals.total OR receipts.id IN (?)", associated_ids)
    else
      scope.where("receipts.charges_total < expense_totals.total")
    end.order(expense_date: :desc)
  end

  def accounted_total
    receipts.joins(:expenses).sum("expenses.amount")
  end
end
