class CsvStatement < ApplicationRecord
  belongs_to :payment_method
  has_one_attached :file

  def date_range
    return unless file.attached?

    dates = []
    file.open do |tmp|
      CSV.foreach(tmp.path, headers: true) do |row|
        date = Date.strptime(row["Date"].to_s, "%m/%d/%Y") rescue nil
        dates << date if date
      end
    end
    dates.minmax if dates.any?
  end
end
