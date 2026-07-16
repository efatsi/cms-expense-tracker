class Receipt < ApplicationRecord
  belongs_to :user
  belongs_to :payment_method
  has_many :expenses, dependent: :destroy
  accepts_nested_attributes_for :expenses, allow_destroy: true, reject_if: :all_blank
  has_many :charge_receipts, dependent: :destroy
  has_many :charges, through: :charge_receipts
  has_one_attached :file

  enum :status, { pending: 0, matched: 1, processing: 2 }, default: :pending

  validates :vendor, :expense_date, :payment_method, presence: true
  validates :expenses, length: { minimum: 1, message: "must have at least one expense" }

  def total_amount
    expenses.sum(&:amount)
  end
end
