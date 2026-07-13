require "csv"

class ReportsController < ApplicationController
  def index
    build_receipts

    respond_to do |format|
      format.html
      format.csv do
        send_data generate_csv, filename: "expenses-#{Date.today}.csv", type: "text/csv"
      end
    end
  end

  private

  def build_receipts
    @receipts = current_user.admin? ? Receipt.all : current_user.receipts
    @receipts = @receipts.includes(:expenses => :expense_category, :payment_method => [], :user => [])

    if current_user.admin? && params[:user_id].present?
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

    @receipts = @receipts.order(expense_date: :desc)
    @categories = ExpenseCategory.active
    @users = User.order(:name) if current_user.admin?
  end

  def generate_csv
    CSV.generate(headers: true) do |csv|
      headers = [ "Date", "Vendor", "Payment Method", "Category", "Description", "Amount" ]
      headers.unshift("Employee") if current_user.admin?

      csv << headers

      @receipts.each do |receipt|
        receipt.expenses.each do |expense|
          row = [
            receipt.expense_date.strftime("%Y-%m-%d"),
            receipt.vendor,
            receipt.payment_method.display_name,
            expense.expense_category.name,
            expense.description,
            expense.amount.to_f
          ]
          row.unshift(receipt.user.name) if current_user.admin?
          csv << row
        end
      end
    end
  end
end
