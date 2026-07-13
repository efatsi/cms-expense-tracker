class AddSectionToExpenseCategories < ActiveRecord::Migration[8.1]
  def change
    add_column :expense_categories, :section, :string
  end
end
