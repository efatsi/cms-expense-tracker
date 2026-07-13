class CreateExpenseCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :expense_categories do |t|
      t.string :name
      t.boolean :active, default: true, null: false

      t.timestamps
    end
  end
end
