namespace :receipts do
  desc "Detect duplicate receipts by vendor, date, and total amount (any 2 of 3 matching)"
  task detect_duplicates: :environment do
    receipts = Receipt.where.not(status: :processing)
                      .includes(:user, :expenses)
                      .order(:expense_date, :vendor)

    # Build a list of comparable structs
    entries = receipts.map do |r|
      { receipt: r, vendor: r.vendor&.downcase&.strip, date: r.expense_date, total: r.total_amount }
    end

    groups = Hash.new { |h, k| h[k] = [] }

    entries.each_with_index do |a, i|
      entries[(i + 1)..].each do |b|
        amount_match = a[:total] > 0 && b[:total] > 0 && a[:total] == b[:total]
        next unless amount_match

        matches = [ :total ]
        matches << :vendor if a[:vendor].present? && b[:vendor].present? && a[:vendor] == b[:vendor]
        matches << :date   if a[:date].present?   && b[:date].present?   && a[:date] == b[:date]

        next if matches.size < 2

        key = [ a[:receipt].id, b[:receipt].id ].sort.join("-")
        groups[key] = { receipts: [ a[:receipt], b[:receipt] ], matches: matches }
      end
    end

    if groups.empty?
      puts "No duplicate receipts found."
      next
    end

    puts "Found #{groups.size} potential duplicate pair(s):\n\n"

    groups.each_value do |group|
      r1, r2 = group[:receipts]
      matched_fields = group[:matches].join(", ")
      puts "  Matched on: #{matched_fields}"
      puts "  ##{r1.id} — #{r1.user.name} | #{r1.vendor} | #{r1.expense_date} | $#{'%.2f' % r1.total_amount}"
      puts "  ##{r2.id} — #{r2.user.name} | #{r2.vendor} | #{r2.expense_date} | $#{'%.2f' % r2.total_amount}"
      puts
    end
  end
end
