class AddApprovedAtToReceipts < ActiveRecord::Migration[8.1]
  def change
    add_column :receipts, :approved_at, :datetime
  end
end
