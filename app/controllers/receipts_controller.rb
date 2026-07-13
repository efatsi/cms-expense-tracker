class ReceiptsController < ApplicationController
  before_action :set_receipt, only: [ :show, :edit, :update, :destroy ]
  before_action :authorize_receipt!, only: [ :show, :edit, :update, :destroy ]

  def index
    @receipts = current_user.admin? ? Receipt.all : current_user.receipts
    @receipts = @receipts.includes(:user, :payment_method, :expenses)
                         .order(expense_date: :desc)
  end

  def show
  end

  def new
    @receipt = Receipt.new
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
