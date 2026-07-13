class CreateReceipts < ActiveRecord::Migration[8.1]
  def change
    create_table :receipts do |t|
      t.references :user, null: false, foreign_key: true
      t.references :payment_method, null: false, foreign_key: true
      t.date :expense_date
      t.string :vendor
      t.text :notes
      t.integer :status, default: 0, null: false

      t.timestamps
    end
  end
end
