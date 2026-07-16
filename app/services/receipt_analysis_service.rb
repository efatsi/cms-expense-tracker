class ReceiptAnalysisService
  require "net/http"
  require "base64"

  def initialize(path:, content_type:, filename:)
    @path = path
    @content_type = content_type.to_s
    @filename = filename.to_s
  end

  def call
    is_pdf = @content_type.include?("pdf") || @filename.end_with?(".pdf")

    result = if is_pdf
      text = extract_pdf_text
      if text.present?
        parse_with_ollama(model: "llama3.2", prompt: pdf_prompt(text), stream: false, format: "json")
      else
        # Image-based PDF — render first page to PNG and use vision model
        image_data = pdf_to_image_base64
        return empty_result if image_data.nil?

        parse_with_ollama(model: "llama3.2-vision", prompt: image_prompt, images: [ image_data ], stream: false, format: "json")
      end
    else
      image_data = Base64.strict_encode64(File.binread(@path))
      parse_with_ollama(model: "llama3.2-vision", prompt: image_prompt, images: [ image_data ], stream: false, format: "json")
    end

    resolve_category_ids(result)
  rescue => e
    Rails.logger.error("ReceiptAnalysisService error: #{e.message}")
    empty_result
  end

  private

  def empty_result
    { "vendor" => nil, "date" => nil, "expenses" => [] }
  end

  def categories_text
    section_descriptions = {
      "Store"        => "camp store retail: merchandise, uniforms, photos, pharmacy",
      "Admin"        => "administrative & operational: insurance, office, marketing, payroll taxes, transportation",
      "Facilities"   => "buildings & grounds: maintenance, repairs, landscaping, plumbing, cleaning supplies",
      "Food Service" => "kitchen & dining: food purchases, kitchen supplies, kitchen staff",
      "Healthcare"   => "camp health center: medical staff and medical supplies",
      "Program"      => "camp activities: counselor salaries, activity supplies, training, certifications"
    }

    ExpenseCategory.active.order(:section, :name).group_by(&:section).map do |section, cats|
      desc = section_descriptions[section] || section
      "#{section} (#{desc}): #{cats.map(&:name).join(', ')}"
    end.join(" | ")
  end

  def pdf_prompt(text)
    <<~PROMPT
      Here is the text extracted from a receipt:

      #{text}

      Return a JSON object with exactly these fields:
      - "vendor": the primary retailer or marketplace that issued the receipt (e.g. "Amazon", "Walmart", "Home Depot") — not a third-party seller listed within the receipt
      - "date": date of purchase in YYYY-MM-DD format, default to #{Date.today} if unclear
      - "expenses": an array containing EXACTLY ONE item summarizing the entire receipt, with:
          - "description": 2-4 word summary of what was purchased (e.g. "Cleaning supplies", "Pet food", "Office paper")
          - "amount": the total amount of the receipt (number, no currency symbol)
          - "category": pick the single best match from this list — most common are "Supplies (Facilities)", "Supplies (Program)", "Supplies (Healthcare)", "Food (Food Service)" — full list: #{categories_text}

      Return ONLY valid JSON. No explanation, no markdown, no code fences.
    PROMPT
  end

  def image_prompt
    <<~PROMPT
      Analyze this receipt image and return a JSON object with exactly these fields:
      - "vendor": the primary retailer or marketplace that issued the receipt (e.g. "Amazon", "Walmart", "Home Depot") — not a third-party seller listed within the receipt
      - "date": date of purchase in YYYY-MM-DD format, default to #{Date.today} if unclear
      - "expenses": an array containing EXACTLY ONE item summarizing the entire receipt, with:
          - "description": 2-4 word summary of what was purchased (e.g. "Cleaning supplies", "Pet food", "Office paper")
          - "amount": the total amount of the receipt (number, no currency symbol)
          - "category": pick the single best match from this list — most common are "Supplies (Facilities)", "Supplies (Program)", "Supplies (Healthcare)", "Food (Food Service)" — full list: #{categories_text}

      Return ONLY valid JSON. No explanation, no markdown, no code fences.
    PROMPT
  end

  def pdf_to_image_base64
    png_path = "#{@path}.png"
    success = system(
      "gs", "-dBATCH", "-dNOPAUSE", "-dSAFER",
      "-sDEVICE=png16m", "-r150",
      "-dFirstPage=1", "-dLastPage=1",
      "-sOutputFile=#{png_path}",
      @path,
      out: File::NULL, err: File::NULL
    )
    return nil unless success && File.exist?(png_path)

    Base64.strict_encode64(File.binread(png_path))
  ensure
    File.delete(png_path) if png_path && File.exist?(png_path)
  end

  def extract_pdf_text
    reader = PDF::Reader.new(@path)
    reader.pages.first(3).map(&:text).join("\n").strip
  rescue => e
    Rails.logger.error("PDF extraction failed: #{e.message}")
    nil
  end

  def parse_with_ollama(body)
    uri = URI("http://localhost:11434/api/generate")
    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = 90

    request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
    request.body = body.to_json

    response = http.request(request)
    raw = JSON.parse(response.body)["response"]
    JSON.parse(raw)
  end

  def resolve_category_ids(parsed)
    category_map = ExpenseCategory.active.each_with_object({}) { |c, h| h[c.name.downcase] = c.id }
    parsed["expenses"]&.each do |expense|
      name = expense["category"].to_s
      expense["category_id"] = category_map[name.downcase] ||
        category_map.find { |k, _| k.include?(name.downcase) || name.downcase.include?(k) }&.last
    end
    parsed
  end
end
