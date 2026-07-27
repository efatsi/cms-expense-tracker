class ExpenseCategory < ApplicationRecord
  has_many :expenses

  scope :active, -> { where(active: true) }

  validates :name, presence: true
end

# == Schema Information
#
# Table name: expense_categories
#
#  id         :bigint           not null, primary key
#  active     :boolean          default(TRUE), not null
#  name       :string
#  section    :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
