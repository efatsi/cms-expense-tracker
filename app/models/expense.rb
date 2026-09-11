class Expense < ApplicationRecord
  belongs_to :receipt
  belongs_to :expense_category

  validates :description, :amount, presence: true
  validates :amount, numericality: { other_than: 0 }
end

# == Schema Information
#
# Table name: expenses
#
#  id                  :bigint           not null, primary key
#  amount              :decimal(10, 2)
#  description         :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  expense_category_id :bigint           not null
#  receipt_id          :bigint           not null
#
# Indexes
#
#  index_expenses_on_expense_category_id  (expense_category_id)
#  index_expenses_on_receipt_id           (receipt_id)
#
# Foreign Keys
#
#  fk_rails_...  (expense_category_id => expense_categories.id)
#  fk_rails_...  (receipt_id => receipts.id)
#
