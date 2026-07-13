require "csv"

class Admin::ChargesController < Admin::BaseController
  before_action :set_charge, only: [ :match ]

  def index
    @charges = Charge.includes(:payment_method, :receipt)
                     .order(transaction_date: :desc)

    if params[:unmatched_only]
      @charges = @charges.unmatched
    end

    @charges = @charges.all
    @payment_methods = PaymentMethod.order(:name)
  end

  def import
    unless params[:file].present?
      return redirect_to admin_charges_path, alert: "Please select a CSV file."
    end

    payment_method = PaymentMethod.find(params[:payment_method_id])
    results = import_csv(params[:file], payment_method)

    redirect_to admin_charges_path,
      notice: "#{results[:imported]} charges imported, #{results[:skipped]} skipped as duplicates."
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_charges_path, alert: "Payment method not found."
  rescue CSV::MalformedCSVError => e
    redirect_to admin_charges_path, alert: "Invalid CSV: #{e.message}"
  end

  def match
    receipt = Receipt.find(params[:receipt_id])
    @charge.update!(receipt: receipt, matched_at: Time.current)
    receipt.update!(status: :matched)
    redirect_to admin_charges_path, notice: "Charge matched to receipt ##{receipt.id}."
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_charges_path, alert: "Receipt not found."
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
    Date.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end
end
