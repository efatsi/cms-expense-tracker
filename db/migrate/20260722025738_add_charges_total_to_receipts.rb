class AddChargesTotalToReceipts < ActiveRecord::Migration[8.1]
  def change
    add_column :receipts, :charges_total, :decimal, precision: 10, scale: 2, default: 0, null: false

    reversible do |dir|
      dir.up do
        Receipt.find_each do |receipt|
          total = ChargeReceipt.joins(:charge).where(receipt_id: receipt.id).sum("charges.amount")
          receipt.update_column(:charges_total, total)
        end
      end
    end
  end
end
