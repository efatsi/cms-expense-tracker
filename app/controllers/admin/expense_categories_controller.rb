class Admin::ExpenseCategoriesController < Admin::BaseController
  before_action :set_category, only: [ :edit, :update, :destroy ]

  def index
    @categories = ExpenseCategory.order(:name)
  end

  def new
    @category = ExpenseCategory.new
  end

  def create
    @category = ExpenseCategory.new(category_params)
    if @category.save
      redirect_to admin_expense_categories_path, notice: "Category created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @category.update(category_params)
      redirect_to admin_expense_categories_path, notice: "Category updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @category.destroy
    redirect_to admin_expense_categories_path, notice: "Category deleted."
  end

  private

  def set_category
    @category = ExpenseCategory.find(params[:id])
  end

  def category_params
    params.require(:expense_category).permit(:name, :active)
  end
end
