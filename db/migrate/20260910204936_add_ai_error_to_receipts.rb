class AddAiErrorToReceipts < ActiveRecord::Migration[8.1]
  def change
    add_column :receipts, :ai_error, :text
  end
end
