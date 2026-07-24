require "csv"

class Admin::ChargesController < Admin::BaseController
  before_action :set_charge, only: [ :show, :associate, :lock_in, :save_expenses ]

  def show
    @charge = Charge.includes(:payment_method,
                               charge_expenses: :expense_category,
                               receipts: [ { expenses: :expense_category }, { file_attachment: :blob } ]).find(params[:id])
    @nearby_receipts = @charge.nearby_receipts
    @associated_receipt = @charge.receipts.first
  end

  def index
    @charges = Charge.includes(:payment_method)
                     .order(transaction_date: :desc)

    if params[:unmatched_only]
      @charges = @charges.unmatched
    end

    if params[:payment_method_id].present?
      @charges = @charges.where(payment_method_id: params[:payment_method_id])
    end

    @charges = @charges.all
    @payment_methods = PaymentMethod.order(:name)
    @csv_statements = CsvStatement.includes(:payment_method).order(created_at: :desc)
  end

  def import
    unless params[:file].present?
      return redirect_to admin_charges_path, alert: "Please select a CSV file."
    end

    payment_method = PaymentMethod.find(params[:payment_method_id])
    results = import_csv(params[:file], payment_method)

    statement = CsvStatement.new(
      payment_method: payment_method,
      imported_count: results[:imported],
      skipped_count: results[:skipped]
    )
    statement.file.attach(params[:file])
    statement.save!

    redirect_to admin_charges_path,
      notice: "#{results[:imported]} charges imported, #{results[:skipped]} skipped as duplicates."
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_charges_path, alert: "Payment method not found."
  rescue CSV::MalformedCSVError => e
    redirect_to admin_charges_path, alert: "Invalid CSV: #{e.message}"
  end

  def associate
    receipt = Receipt.find(params[:receipt_id])
    previously_associated = @charge.receipts.to_a

    if @charge.receipts.include?(receipt)
      @charge.receipts.delete(receipt)
    else
      @charge.receipts = [ receipt ]
    end

    (previously_associated + [ receipt ]).uniq.each do |r|
      r.update_column(:charges_total, r.charges.reload.sum(:amount))
    end

    redirect_to admin_charge_path(@charge)
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_charge_path(@charge), alert: "Receipt not found."
  end

  def save_expenses
    rows = (params[:charge_expenses] || {}).values
    rows = rows.reject { |r| r[:amount].blank? && r[:description].blank? }

    if rows.empty?
      return redirect_to admin_charge_path(@charge), alert: "Please add at least one expense."
    end

    ActiveRecord::Base.transaction do
      @charge.charge_expenses.destroy_all
      rows.each do |row|
        @charge.charge_expenses.create!(
          expense_category_id: row[:expense_category_id],
          description: row[:description],
          amount: row[:amount]
        )
      end
      @charge.update!(matched_at: Time.current)
    end

    redirect_to admin_charge_path(@charge), notice: "Expenses saved and charge marked as matched."
  end

  def lock_in
    @charge.update!(matched_at: Time.current)
    @charge.receipts.each { |r| r.update!(status: :matched) }
    redirect_to admin_charge_path(@charge), notice: "Charge locked in."
  end

  private

  def set_charge
    @charge = Charge.find(params[:id])
  end

  def import_csv(file, payment_method)
    imported = 0
    skipped = 0

    CSV.foreach(file.path, headers: true) do |row|
      date = parse_date(row["Date"])
      amount = row["Amount"].to_s.gsub(/[,$]/, "").to_d
      description = row["Description"].to_s.strip

      next if date.nil? || amount.zero? || description.blank?

      exists = Charge.exists?(
        payment_method: payment_method,
        transaction_date: date,
        amount: amount,
        description: description
      )

      if exists
        skipped += 1
      else
        Charge.create!(
          payment_method: payment_method,
          transaction_date: date,
          amount: amount,
          description: description
        )
        imported += 1
      end
    end

    { imported: imported, skipped: skipped }
  end

  def parse_date(value)
    Date.strptime(value.to_s, "%m/%d/%Y")
  rescue ArgumentError, TypeError
    nil
  end
end
