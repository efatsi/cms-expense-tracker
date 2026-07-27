class PaymentMethod < ApplicationRecord
  has_many :receipts
  has_many :charges

  validates :name, presence: true

  def display_name
    account_last_four.present? ? "#{name} (****#{account_last_four})" : name
  end
end

# == Schema Information
#
# Table name: payment_methods
#
#  id                :bigint           not null, primary key
#  account_last_four :string
#  name              :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
