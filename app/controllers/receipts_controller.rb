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

  def analyze
    return render json: { error: "No file" }, status: :bad_request unless params[:file].present?

    result = parse_with_ollama(params[:file])
    render json: result
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
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

  def parse_with_ollama(file)
    require "net/http"
    require "base64"

    section_descriptions = {
      "Store"        => "camp store retail: merchandise, uniforms, photos, pharmacy",
      "Admin"        => "administrative & operational: insurance, office, marketing, payroll taxes, transportation",
      "Facilities"   => "buildings & grounds: maintenance, repairs, landscaping, plumbing, cleaning supplies",
      "Food Service" => "kitchen & dining: food purchases, kitchen supplies, kitchen staff",
      "Healthcare"   => "camp health center: medical staff and medical supplies",
      "Program"      => "camp activities: counselor salaries, activity supplies, training, certifications"
    }

    categories = ExpenseCategory.active.order(:section, :name).group_by(&:section).map do |section, cats|
      desc = section_descriptions[section] || section
      "#{section} (#{desc}): #{cats.map(&:name).join(', ')}"
    end.join(" | ")
    is_pdf = file.content_type.to_s.include?("pdf") || file.original_filename.to_s.end_with?(".pdf")

    body = if is_pdf
      text = extract_pdf_text(file.path)
      return { "vendor" => nil, "date" => nil, "expenses" => [] } if text.blank?

      prompt = <<~PROMPT
        Here is the text extracted from a receipt:

        #{text}

        Return a JSON object with exactly these fields:
        - "vendor": the primary retailer or marketplace that issued the receipt (e.g. "Amazon", "Walmart", "Home Depot") — not a third-party seller listed within the receipt
        - "date": date of purchase in YYYY-MM-DD format, default to #{Date.today} if unclear
        - "expenses": an array containing EXACTLY ONE item summarizing the entire receipt, with:
            - "description": 2-4 word summary of what was purchased (e.g. "Cleaning supplies", "Pet food", "Office paper")
            - "amount": the total amount of the receipt (number, no currency symbol)
            - "category": pick the single best match from this list — most common are "Supplies (Facilities)", "Supplies (Program)", "Supplies (Healthcare)", "Food (Food Service)" — full list: #{categories}

        Return ONLY valid JSON. No explanation, no markdown, no code fences.
      PROMPT

      { model: "llama3.2", prompt: prompt, stream: false, format: "json" }
    else
      image_data = Base64.strict_encode64(file.read)

      prompt = <<~PROMPT
        Analyze this receipt image and return a JSON object with exactly these fields:
        - "vendor": the primary retailer or marketplace that issued the receipt (e.g. "Amazon", "Walmart", "Home Depot") — not a third-party seller listed within the receipt
        - "date": date of purchase in YYYY-MM-DD format, default to #{Date.today} if unclear
        - "expenses": an array containing EXACTLY ONE item summarizing the entire receipt, with:
            - "description": 2-4 word summary of what was purchased (e.g. "Cleaning supplies", "Pet food", "Office paper")
            - "amount": the total amount of the receipt (number, no currency symbol)
            - "category": pick the single best match from this list — most common are "Supplies (Facilities)", "Supplies (Program)", "Supplies (Healthcare)", "Food (Food Service)" — full list: #{categories}

        Return ONLY valid JSON. No explanation, no markdown, no code fences.
      PROMPT

      { model: "llava", prompt: prompt, images: [ image_data ], stream: false, format: "json" }
    end

    uri = URI("http://localhost:11434/api/generate")
    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = 90

    request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
    request.body = body.to_json

    response = http.request(request)
    raw = JSON.parse(response.body)["response"]
    parsed = JSON.parse(raw)

    # Resolve category names to IDs
    category_map = ExpenseCategory.active.each_with_object({}) { |c, h| h[c.name.downcase] = c.id }
    parsed["expenses"]&.each do |expense|
      name = expense["category"].to_s
      expense["category_id"] = category_map[name.downcase] ||
        category_map.find { |k, _| k.include?(name.downcase) || name.downcase.include?(k) }&.last
    end

    parsed
  end

  def extract_pdf_text(path)
    reader = PDF::Reader.new(path)
    reader.pages.first(3).map(&:text).join("\n").strip
  rescue => e
    Rails.logger.error("PDF extraction failed: #{e.message}")
    nil
  end

  def receipt_params
    params.require(:receipt).permit(
      :vendor, :expense_date, :payment_method_id, :notes, :file,
      expenses_attributes: [ :id, :expense_category_id, :description, :amount, :_destroy ]
    )
  end
end
