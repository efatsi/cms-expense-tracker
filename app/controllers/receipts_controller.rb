class ReceiptsController < ApplicationController
  before_action :set_receipt, only: [ :show, :edit, :update, :destroy, :approve, :reprocess ]
  before_action :authorize_receipt!, only: [ :show, :edit, :update, :destroy, :approve, :reprocess ]
  before_action :require_admin!, only: [ :bulk_upload ]

  RECEIPT_FILTER_PARAMS = %w[user_id unmatched_charges].freeze

  def index
    if current_user.admin?
      @filter_params = resolve_filters(:receipts_filters, RECEIPT_FILTER_PARAMS)
      @users = User.order(:name)
      @filtered_user = User.find_by(id: @filter_params[:user_id])
      @receipts = @filtered_user ? @filtered_user.receipts : Receipt.all
      @show_all = @filtered_user.nil?
      @receipts = @receipts.includes(:user, :payment_method, :charges, expenses: :expense_category)
                           .order(expense_date: :desc)
      if @filter_params[:unmatched_charges].present?
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

  def reprocess
    AnalyzeReceiptJob.new.perform(@receipt.id)
    head :ok
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

    uploaded = Array(params[:files]).flatten.compact
    if uploaded.empty?
      flash.now[:alert] = "Please select at least one file."
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
      # Expand all uploads into a flat list of { path:, filename:, content_type: }
      entries = []
      uploaded.each do |file|
        name = file.original_filename.to_s
        if file.content_type == "application/zip" || name.end_with?(".zip")
          Zip::File.open(file.path) do |zip_file|
            zip_file.each do |entry|
              next if entry.directory?
              next if File.basename(entry.name).start_with?(".")
              next if entry.name.include?("__MACOSX")
              next unless entry.name.match?(/\.(jpg|jpeg|png|gif|pdf)$/i)
              tmp_path = File.join(tmpdir, "#{entries.size}_#{File.basename(entry.name)}")
              entry.get_input_stream { |is| File.binwrite(tmp_path, is.read) }
              ext = File.extname(entry.name).downcase
              ct = ext == ".pdf" ? "application/pdf" : "image/#{ext.delete('.')}"
              entries << { path: tmp_path, filename: File.basename(entry.name), content_type: ct }
            end
          end
        elsif name.match?(/\.(jpg|jpeg|png|gif|pdf)$/i)
          entries << { path: file.path, filename: name, content_type: file.content_type }
        end
      end

      entries.each do |entry|
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
            io: File.open(entry[:path], "rb"),
            filename: entry[:filename],
            content_type: entry[:content_type]
          )
          AnalyzeReceiptJob.perform_later(receipt.id)
          count += 1
        else
          errors << "#{entry[:filename]}: #{receipt.errors.full_messages.join(', ')}"
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

  def resolve_filters(cookie_key, filter_keys)
    if filter_keys.any? { |k| params.key?(k) }
      saved = filter_keys.each_with_object({}) { |k, h| h[k] = params[k] if params[k].present? }
      cookies[cookie_key] = { value: saved.to_json, expires: 1.year.from_now }
      params
    else
      saved = cookies[cookie_key].present? ? (JSON.parse(cookies[cookie_key]) rescue {}) : {}
      @restore_url = request.path + (saved.any? ? "?#{saved.to_query}" : "") if saved.any?
      ActionController::Parameters.new(saved)
    end
  end

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
