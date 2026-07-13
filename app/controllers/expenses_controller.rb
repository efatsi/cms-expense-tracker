class ExpensesController < ApplicationController
  before_action :set_receipt
  before_action :authorize_receipt!

  def new
    @expense = @receipt.expenses.build
  end

  def create
    @expense = @receipt.expenses.build(expense_params)
    if @expense.save
      redirect_to @receipt, notice: "Expense added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @expense = @receipt.expenses.find(params[:id])
  end

  def update
    @expense = @receipt.expenses.find(params[:id])
    if @expense.update(expense_params)
      redirect_to @receipt, notice: "Expense updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @expense = @receipt.expenses.find(params[:id])
    @expense.destroy
    redirect_to @receipt, notice: "Expense removed."
  end

  private

  def set_receipt
    @receipt = Receipt.find(params[:receipt_id])
  end

  def authorize_receipt!
    unless current_user.admin? || @receipt.user == current_user
      redirect_to receipts_path, alert: "Not authorized."
    end
  end

  def expense_params
    params.require(:expense).permit(:expense_category_id, :description, :amount)
  end
end
