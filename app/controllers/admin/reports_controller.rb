class Admin::ReportsController < Admin::BaseController
  def index
    @receipts = Receipt.includes(:user, :expenses, :payment_method)

    if params[:user_id].present?
      @receipts = @receipts.where(user_id: params[:user_id])
    end
    if params[:start_date].present?
      @receipts = @receipts.where("expense_date >= ?", params[:start_date])
    end
    if params[:end_date].present?
      @receipts = @receipts.where("expense_date <= ?", params[:end_date])
    end
    if params[:expense_category_id].present?
      @receipts = @receipts.joins(:expenses).where(expenses: { expense_category_id: params[:expense_category_id] })
    end
    if params[:status].present?
      @receipts = @receipts.where(status: params[:status])
    end

    @receipts = @receipts.order(expense_date: :desc)

    @users = User.order(:name)
    @categories = ExpenseCategory.order(:name)
  end
end
