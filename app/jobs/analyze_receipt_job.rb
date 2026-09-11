class AnalyzeReceiptJob < ApplicationJob
  queue_as :default

  def perform(receipt_id)
    receipt = Receipt.find(receipt_id)
    return unless receipt.file.attached?

    fallback_category_id = ExpenseCategory.active.find_by(name: "Uncategorized")&.id || ExpenseCategory.active.first&.id

    receipt.file.open do |tmp|
      result = ReceiptAnalysisService.new(
        path: tmp.path,
        content_type: receipt.file.content_type,
        filename: receipt.file.filename.to_s
      ).call

      if result["vendor"].nil? && result["expenses"].blank?
        receipt.update_columns(status: 0) # reset to pending for manual review
        return
      end

      receipt.vendor = result["vendor"] if result["vendor"].present?
      receipt.expense_date = Date.parse(result["date"]) rescue nil if result["date"].present?
      receipt.status = :pending

      if result["expenses"].present?
        receipt.expenses.destroy_all
        result["expenses"].each do |exp|
          category_id = exp["category_id"] || fallback_category_id
          next unless category_id
          receipt.expenses.build(
            description: exp["description"].presence || "Expense",
            amount: exp["amount"].to_f.nonzero? || 0.01,
            expense_category_id: category_id
          )
        end
      end
      receipt.save!
    end
  rescue => e
    Rails.logger.error("AnalyzeReceiptJob failed for receipt #{receipt_id}: #{e.message}")
    Receipt.find_by(id: receipt_id)&.update_columns(status: 0, ai_error: e.message)
  end
end
