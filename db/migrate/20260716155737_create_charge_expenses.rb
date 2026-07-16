class CreateChargeExpenses < ActiveRecord::Migration[8.1]
  def change
    create_table :charge_expenses do |t|
      t.references :charge, null: false, foreign_key: true
      t.references :expense_category, null: false, foreign_key: true
      t.string :description
      t.decimal :amount, precision: 10, scale: 2

      t.timestamps
    end
  end
end
