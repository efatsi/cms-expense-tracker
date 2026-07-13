class ReceiptsController < ApplicationController
  before_action :set_receipt, only: [ :show, :edit, :update, :destroy ]
  before_action :authorize_receipt!, only: [ :show, :edit, :update, :destroy ]

  def index
    @show_all = current_user.admin? && params[:all] == "1"
    @receipts = @show_all ? Receipt.all : current_user.receipts
    @receipts = @receipts.includes(:user, :payment_method, :expenses)
                         .order(expense_date: :desc)
  end

  def show
  end

  def new
    @receipt = Receipt.new(payment_method_id: current_user.default_payment_method_id, expense_date: Date.today)
    @receipt.expenses.build
  end

  def create
    @receipt = current_user.receipts.build(receipt_params)
    if @receipt.save
      redirect_to @receipt, notice: "Receipt submitted successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @receipt.update(receipt_params)
      redirect_to @receipt, notice: "Receipt updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @receipt.destroy
    redirect_to receipts_path, notice: "Receipt deleted."
  end

  private

  def set_receipt
    @receipt = Receipt.find(params[:id])
  end

  def authorize_receipt!
    unless current_user.admin? || @receipt.user == current_user
      redirect_to receipts_path, alert: "Not authorized."
    end
  end

  def receipt_params
    params.require(:receipt).permit(
      :vendor, :expense_date, :payment_method_id, :notes, :file,
      expenses_attributes: [ :id, :expense_category_id, :description, :amount, :_destroy ]
    )
  end
end
