class AddBarnExpenseCategories < ActiveRecord::Migration[8.0]
  def up
    [
      "Building / Grounds",
      "Horsecare"
    ].each do |name|
      ExpenseCategory.find_or_create_by!(name: name, section: "Barn") do |ec|
        ec.active = true
      end
    end
  end

  def down
    ExpenseCategory.where(section: "Barn").destroy_all
  end
end
