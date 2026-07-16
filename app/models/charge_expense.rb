class ChargeExpense < ApplicationRecord
  belongs_to :charge
  belongs_to :expense_category
end
