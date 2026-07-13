class ReportsController < ApplicationController
  def index
    @receipts = current_user.receipts.includes(:expenses, :payment_method, :user)

    if params[:start_date].present?
      @receipts = @receipts.where("expense_date >= ?", params[:start_date])
    end
    if params[:end_date].present?
      @receipts = @receipts.where("expense_date <= ?", params[:end_date])
    end
    if params[:expense_category_id].present?
      @receipts = @receipts.joins(:expenses).where(expenses: { expense_category_id: params[:expense_category_id] })
    end

    @receipts = @receipts.order(expense_date: :desc)
    @categories = ExpenseCategory.active
  end
end
