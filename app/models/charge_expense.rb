class ChargeExpense < ApplicationRecord
  belongs_to :charge
  belongs_to :expense_category
end

# == Schema Information
#
# Table name: charge_expenses
#
#  id                  :bigint           not null, primary key
#  amount              :decimal(10, 2)
#  description         :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  charge_id           :bigint           not null
#  expense_category_id :bigint           not null
#
# Indexes
#
#  index_charge_expenses_on_charge_id            (charge_id)
#  index_charge_expenses_on_expense_category_id  (expense_category_id)
#
# Foreign Keys
#
#  fk_rails_...  (charge_id => charges.id)
#  fk_rails_...  (expense_category_id => expense_categories.id)
#
