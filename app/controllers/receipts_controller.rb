class ReceiptsController < ApplicationController
  before_action :set_receipt, only: [ :show, :edit, :update, :destroy, :approve ]
  before_action :authorize_receipt!, only: [ :show, :edit, :update, :destroy, :approve ]
  before_action :require_admin!, only: [ :bulk_upload ]

  def index
    if current_user.admin?
      @users = User.order(:name)
      @filtered_user = User.find_by(id: params[:user_id])
      @receipts = @filtered_user ? @filtered_user.receipts : Receipt.all
      @show_all = @filtered_user.nil?
      @receipts = @receipts.includes(:user, :payment_method, :charges, expenses: :expense_category)
                           .order(expense_date: :desc)
      if params[:unmatched_charges].present?
        @receipts = @receipts.reject { |r| r.charges.sum(&:amount) >= r.total_amount }
      end
    else
      @receipts = current_user.receipts
                              .includes(:user, :payment_method, expenses: :expense_category)
                              .order(expense_date: :desc)
      @show_all = false
    end
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
    if @receipt.update(receipt_params.merge(approved_at: Time.current))
      redirect_to @receipt, notice: "Receipt updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def approve
    @receipt.update!(approved_at: Time.current)
    redirect_to @receipt, notice: "Receipt categorization approved."
  end

  def destroy
    @receipt.destroy
    redirect_to receipts_path, notice: "Receipt deleted."
  end

  def analyze
    return render json: { vendor: nil, date: nil, expenses: [] } if Rails.env.production?
    return render json: { error: "No file" }, status: :bad_request unless params[:file].present?

    file = params[:file]
    result = ReceiptAnalysisService.new(
      path: file.path,
      content_type: file.content_type,
      filename: file.original_filename
    ).call
    render json: result
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def bulk_upload
    @users = User.order(:name)
    return unless request.post?

    user = User.find_by(email: params[:user_email])
    unless user
      flash.now[:alert] = "No user found with email: #{params[:user_email]}"
      return render :bulk_upload
    end

    zip = params[:zip_file]
    unless zip
      flash.now[:alert] = "Please select a zip file."
      return render :bulk_upload
    end

    payment_method = user.default_payment_method || PaymentMethod.first
    unless payment_method
      flash.now[:alert] = "No payment method available. Please configure one first."
      return render :bulk_upload
    end

    fallback_category = ExpenseCategory.active.first
    unless fallback_category
      flash.now[:alert] = "No expense categories found. Please configure categories first."
      return render :bulk_upload
    end

    count = 0
    errors = []

    require "zip"
    Dir.mktmpdir do |tmpdir|
      Zip::File.open(zip.path) do |zip_file|
        zip_file.each do |entry|
          next if entry.directory?
          next if File.basename(entry.name).start_with?(".")
          next if entry.name.include?("__MACOSX")
          next unless entry.name.match?(/\.(jpg|jpeg|png|gif|pdf)$/i)

          tmp_path = File.join(tmpdir, File.basename(entry.name))
          entry.get_input_stream { |is| File.binwrite(tmp_path, is.read) }

          ext = File.extname(entry.name).downcase
          content_type = ext == ".pdf" ? "application/pdf" : "image/#{ext.delete('.')}"

          receipt = user.receipts.build(
            vendor: "Processing...",
            expense_date: Date.today,
            payment_method: payment_method,
            status: :processing
          )
          receipt.expenses.build(
            description: "Processing...",
            amount: 0.01,
            expense_category: fallback_category
          )

          if receipt.save
            receipt.file.attach(
              io: File.open(tmp_path, "rb"),
              filename: File.basename(entry.name),
              content_type: content_type
            )
            AnalyzeReceiptJob.perform_later(receipt.id)
            count += 1
          else
            errors << "#{File.basename(entry.name)}: #{receipt.errors.full_messages.join(', ')}"
          end
        end
      end
    end

    if errors.any?
      flash.now[:alert] = "#{count} receipts queued, #{errors.size} failed: #{errors.first(3).join('; ')}"
      render :bulk_upload
    else
      redirect_to receipts_path(all: 1), notice: "#{count} receipts uploaded and queued for AI analysis."
    end
  rescue => e
    flash.now[:alert] = "Error processing zip: #{e.message}"
    render :bulk_upload
  end

  private

  def set_receipt
    @receipt = Receipt.includes(:charges, expenses: :expense_category).find(params[:id])
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
