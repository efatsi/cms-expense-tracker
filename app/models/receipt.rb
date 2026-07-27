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

# == Schema Information
#
# Table name: receipts
#
#  id                :bigint           not null, primary key
#  approved_at       :datetime
#  charges_total     :decimal(10, 2)   default(0.0), not null
#  expense_date      :date
#  notes             :text
#  status            :integer          default(0), not null
#  vendor            :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  payment_method_id :bigint           not null
#  user_id           :bigint           not null
#
# Indexes
#
#  index_receipts_on_payment_method_id  (payment_method_id)
#  index_receipts_on_user_id            (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (payment_method_id => payment_methods.id)
#  fk_rails_...  (user_id => users.id)
#
