class ChargeReceipt < ApplicationRecord
  belongs_to :charge
  belongs_to :receipt
end
