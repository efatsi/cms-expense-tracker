class CreateExpenses < ActiveRecord::Migration[8.1]
  def change
    create_table :expenses do |t|
      t.references :receipt, null: false, foreign_key: true
      t.references :expense_category, null: false, foreign_key: true
      t.string :description
      t.decimal :amount, precision: 10, scale: 2

      t.timestamps
    end
  end
end
