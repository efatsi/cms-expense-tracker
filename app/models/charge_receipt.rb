class ChargeReceipt < ApplicationRecord
  belongs_to :charge
  belongs_to :receipt
end

# == Schema Information
#
# Table name: charge_receipts
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  charge_id  :bigint           not null
#  receipt_id :bigint           not null
#
# Indexes
#
#  index_charge_receipts_on_charge_id                 (charge_id)
#  index_charge_receipts_on_charge_id_and_receipt_id  (charge_id,receipt_id) UNIQUE
#  index_charge_receipts_on_receipt_id                (receipt_id)
#
# Foreign Keys
#
#  fk_rails_...  (charge_id => charges.id)
#  fk_rails_...  (receipt_id => receipts.id)
#
