class PaymentMethod < ApplicationRecord
  has_many :receipts
  has_many :charges

  validates :name, presence: true

  def display_name
    account_last_four.present? ? "#{name} (****#{account_last_four})" : name
  end
end
