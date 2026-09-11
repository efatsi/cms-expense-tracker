require "csv"

class Admin::ChargesController < Admin::BaseController
  before_action :set_charge, only: [ :show, :associate, :lock_in, :reset_match, :save_expenses ]

  def show
    @charge = Charge.includes(:payment_method,
                               charge_expenses: :expense_category,
                               receipts: [ { expenses: :expense_category }, { file_attachment: :blob } ]).find(params[:id])
    @nearby_receipts = @charge.nearby_receipts
    @associated_receipt = @charge.receipts.first
  end

  CHARGE_FILTER_PARAMS = %w[payment_method_id unmatched_only].freeze

  SORT_COLUMN_MAP = {
    "col-date"        => "charges.transaction_date",
    "col-amount"      => "charges.amount",
    "col-description" => "charges.description",
    "col-status"      => "charges.matched_at",
    "col-method"      => "payment_methods.name"
  }.freeze

  def index
    @filter_params = resolve_filters(:charges_filters, CHARGE_FILTER_PARAMS)
    @charges = Charge.includes(:payment_method, charge_expenses: :expense_category, receipts: { expenses: :expense_category })
                     .order(transaction_date: :desc)

    if @filter_params[:unmatched_only].present?
      @charges = @charges.unmatched
    end

    if @filter_params[:payment_method_id].present?
      @charges = @charges.where(payment_method_id: @filter_params[:payment_method_id])
    end

    @charges = @charges.all
    @payment_methods = PaymentMethod.order(:name)
  end

  def export
    sort_col   = SORT_COLUMN_MAP[params[:sort]]
    sort_order = params[:order] == "asc" ? "asc" : "desc"

    charges = Charge.includes(:payment_method, charge_expenses: :expense_category, receipts: { expenses: :expense_category, charges: [] })
    charges = charges.where(payment_method_id: params[:payment_method_id]) if params[:payment_method_id].present?
    charges = if sort_col
      charges.joins(:payment_method).order(Arel.sql("#{sort_col} #{sort_order}"))
    else
      charges.order(transaction_date: :desc)
    end

    all_charges = charges.to_a

    # Pre-compute expense distributions per receipt across all its charges
    receipt_distributions = {}
    all_charges.each do |charge|
      charge.receipts.each do |receipt|
        next if receipt_distributions.key?(receipt.id)
        receipt_distributions[receipt.id] = distribute_receipt_expenses(receipt)
      end
    end

    csv_data = CSV.generate(headers: true) do |csv|
      csv << [ "Date", "Payment Method", "Description", "Amount", "Expense Category", "Expense Description", "Expense Amount" ]

      all_charges.each do |charge|
        charge_cols = [
          charge.transaction_date.strftime("%m/%d/%Y"),
          charge.payment_method.display_name,
          charge.description,
          charge.amount
        ]

        expense_rows = []

        charge.receipts.each do |receipt|
          distribution = receipt_distributions[receipt.id] || {}
          (distribution[charge.id] || []).each do |exp, allocated|
            cat = exp.expense_category
            expense_rows << [ cat && "#{cat.section}: #{cat.name}", exp.description, allocated.round(2) ]
          end
        end

        charge.charge_expenses.each do |exp|
          cat = exp.expense_category
          expense_rows << [ cat && "#{cat.section}: #{cat.name}", exp.description, exp.amount ]
        end

        if expense_rows.empty?
          csv << charge_cols + [ nil, nil, nil ]
        else
          expense_rows.each_with_index do |exp_row, i|
            csv << (i == 0 ? charge_cols : [ nil, nil, nil, nil ]) + exp_row
          end
        end
      end
    end

    send_data csv_data, filename: "charges-#{Date.today}.csv", type: "text/csv", disposition: "attachment"
  end

  def auto_associate
    unmatched = Charge.unmatched.includes(:payment_method, :receipts)
    count = 0

    unmatched.each do |charge|
      nearby = charge.nearby_receipts
      amount_matches = nearby.select { |r| r.total_amount == charge.amount }
      next unless amount_matches.size == 1

      receipt = amount_matches.first
      charge.charge_expenses.destroy_all
      charge.receipts = [ receipt ]
      receipt.update_column(:charges_total, receipt.charges.reload.sum(:amount))
      charge.update!(matched_at: Time.current)
      receipt.update!(status: :matched)
      count += 1
    end

    redirect_to admin_charges_path, notice: "#{count} charge#{'s' unless count == 1} auto-associated."
  end

  def import
    if request.get?
      @payment_methods = PaymentMethod.order(:name)
      @csv_statements = CsvStatement.includes(:payment_method).order(created_at: :desc)
      return
    end

    unless params[:file].present?
      return redirect_to import_admin_charges_path, alert: "Please select a CSV file."
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

    redirect_to import_admin_charges_path,
      notice: "#{results[:imported]} charges imported, #{results[:skipped]} skipped as duplicates."
  rescue ActiveRecord::RecordNotFound
    redirect_to import_admin_charges_path, alert: "Payment method not found."
  rescue CSV::MalformedCSVError => e
    redirect_to import_admin_charges_path, alert: "Invalid CSV: #{e.message}"
  end

  def associate
    receipt = Receipt.find(params[:receipt_id])
    previously_associated = @charge.receipts.to_a

    if @charge.receipts.include?(receipt)
      @charge.receipts.delete(receipt)
    else
      @charge.charge_expenses.destroy_all
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
      @charge.receipts.clear
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

  def reset_match
    @charge.update!(matched_at: nil)
    previously_associated = @charge.receipts.to_a
    @charge.receipts.each { |r| r.update!(status: :pending) }
    @charge.receipts.clear
    previously_associated.each { |r| r.update_column(:charges_total, r.charges.reload.sum(:amount)) }
    redirect_to admin_charge_path(@charge), notice: "Charge reset to unmatched."
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

  # Distributes a receipt's expenses across its charges, biggest to smallest.
  # Returns a hash of charge_id => [[expense, allocated_amount], ...]
  def distribute_receipt_expenses(receipt)
    sorted_charges = receipt.charges.sort_by { |c| -c.amount.to_f.abs }
    sorted_expenses = receipt.expenses.sort_by { |e| -e.amount.to_f.abs }

    expense_pool = sorted_expenses.map { |e| [e, e.amount.to_f.abs] }
    exp_idx = 0
    distribution = {}

    sorted_charges.each do |charge|
      rows = []
      remaining = charge.amount.to_f.abs
      sign = charge.amount.to_f >= 0 ? 1 : -1

      while remaining > 0.001 && exp_idx < expense_pool.size
        exp, exp_remaining = expense_pool[exp_idx]

        if exp_remaining <= remaining + 0.001
          rows << [exp, exp_remaining * sign]
          remaining -= exp_remaining
          expense_pool[exp_idx][1] = 0
          exp_idx += 1
        else
          rows << [exp, remaining * sign]
          expense_pool[exp_idx][1] -= remaining
          remaining = 0
        end
      end

      distribution[charge.id] = rows
    end

    distribution
  end
end
