module ApplicationHelper
  def grouped_expense_category_options(selected = nil)
    groups = ExpenseCategory.active.order(:section, :name).group_by(&:section).map do |section, cats|
      [ section, cats.map { |c| [ c.name, c.id ] } ]
    end
    grouped_options_for_select(groups, selected)
  end
end
