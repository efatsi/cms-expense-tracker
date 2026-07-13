class CreateCharges < ActiveRecord::Migration[8.1]
  def change
    create_table :charges do |t|
      t.references :payment_method, null: false, foreign_key: true
      t.date :transaction_date
      t.decimal :amount, precision: 10, scale: 2
      t.string :description
      t.references :receipt, null: true, foreign_key: true
      t.datetime :matched_at

      t.timestamps
    end
  end
end
