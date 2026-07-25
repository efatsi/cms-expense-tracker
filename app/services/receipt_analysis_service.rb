class ReceiptAnalysisService
  require "base64"

  MODEL = "claude-opus-4-6"

  def initialize(path:, content_type:, filename:)
    @path = path
    @content_type = content_type.to_s
    @filename = filename.to_s
  end

  def call
    is_pdf = @content_type.include?("pdf") || @filename.end_with?(".pdf")
    sanitize_pdf! if is_pdf

    result = if is_pdf
      text = extract_pdf_text
      if text.present?
        parse_with_claude(prompt: pdf_prompt(text))
      else
        image_data = pdf_to_image_base64
        return empty_result if image_data.nil?

        parse_with_claude(prompt: image_prompt, image_data: image_data, media_type: "image/png")
      end
    else
      image_data = Base64.strict_encode64(File.binread(@path))
      parse_with_claude(prompt: image_prompt, image_data: image_data, media_type: @content_type)
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

  def client
    @client ||= Anthropic::Client.new(
      api_key: Rails.application.credentials.anthropic_api_key!
    )
  end

  def parse_with_claude(prompt:, image_data: nil, media_type: nil)
    content = if image_data
      [
        {
          type: "image",
          source: {
            type: "base64",
            media_type: media_type,
            data: image_data
          }
        },
        { type: "text", text: prompt }
      ]
    else
      prompt
    end

    message = client.messages.create(
      model: MODEL,
      max_tokens: 1024,
      messages: [ { role: "user", content: content } ]
    )

    Rails.logger.info("ReceiptAnalysisService tokens — input: #{message.usage.input_tokens}, output: #{message.usage.output_tokens}")
    result = JSON.parse(message.content.first.text)
    Rails.logger.info("ReceiptAnalysisService result:\n#{JSON.pretty_generate(result)}")
    result
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
          - "amount": the total amount the customer paid. Look for labels like "Order Total", "Grand Total", "Total", or "Amount Charged" — these are the authoritative final amount. If the receipt is an image and any text or amount appears highlighted or in a distinct color, that highlighted value is the grand total. If you see separate "Subtotal" and "Tax" lines, ADD them together. Do NOT use a line-item TOTAL column from a table — that is a per-item price, not the invoice total.
          - "category": pick the single best match from this list — use the exact category name. Common mappings: hardware/building/facility supplies → "Building Maintenance / Repairs"; cleaning supplies → "Cleaning Supplies"; food/groceries → "Food"; kitchen supplies → "Kitchen Supplies"; pillbox/pill organizer/medical supplies → "Supplies" (Healthcare); activity/camp/program supplies → "Supplies" (Program); clothing/uniforms/merch → "Merch + Uniforms". Only use "Miscellaneous" if nothing else fits. Full list: #{categories_text}

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
          - "amount": the total amount the customer paid. Look for labels like "Order Total", "Grand Total", "Total", or "Amount Charged" — these are the authoritative final amount. If the receipt is an image and any text or amount appears highlighted or in a distinct color, that highlighted value is the grand total. If you see separate "Subtotal" and "Tax" lines, ADD them together. Do NOT use a line-item TOTAL column from a table — that is a per-item price, not the invoice total.
          - "category": pick the single best match from this list — use the exact category name. Common mappings: hardware/building/facility supplies → "Building Maintenance / Repairs"; cleaning supplies → "Cleaning Supplies"; food/groceries → "Food"; kitchen supplies → "Kitchen Supplies"; pillbox/pill organizer/medical supplies → "Supplies" (Healthcare); activity/camp/program supplies → "Supplies" (Program); clothing/uniforms/merch → "Merch + Uniforms". Only use "Miscellaneous" if nothing else fits. Full list: #{categories_text}

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

  def sanitize_pdf!
    data = File.binread(@path)
    eof_pos = data.rindex("%%EOF")
    return unless eof_pos

    end_pos = eof_pos + 5
    end_pos += 1 if end_pos < data.size && data.byteslice(end_pos) =~ /[\r\n]/
    return if end_pos >= data.size # nothing trailing

    tmp = Tempfile.new([ "cleaned", ".pdf" ])
    tmp.binmode
    tmp.write(data.byteslice(0, end_pos))
    tmp.close
    @_sanitized_tmp = tmp # prevent GC
    Rails.logger.info("ReceiptAnalysisService: stripped #{data.size - end_pos} bytes after %%EOF")
    @path = tmp.path
  end

  def extract_pdf_text
    reader = PDF::Reader.new(@path)
    reader.pages.first(3).map(&:text).join("\n").strip
  rescue => e
    Rails.logger.error("PDF extraction failed: #{e.message}")
    nil
  end

  def resolve_category_ids(parsed)
    categories = ExpenseCategory.active.to_a
    category_map = categories.each_with_object({}) { |c, h| h[c.name.downcase] = c.id }
    section_map = categories.group_by { |c| c.section.downcase }

    parsed["expenses"]&.each do |expense|
      name = expense["category"].to_s.downcase
      expense["category_id"] = category_map[name] ||
        category_map.find { |k, _| k.include?(name) || name.include?(k) }&.last ||
        section_map[name]&.find { |c| c.name.downcase.include?("supplies") }&.id ||
        section_map[name]&.first&.id
    end
    parsed
  end
end
