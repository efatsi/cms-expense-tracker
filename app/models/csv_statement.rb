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

# == Schema Information
#
# Table name: csv_statements
#
#  id                :bigint           not null, primary key
#  imported_count    :integer
#  skipped_count     :integer
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  payment_method_id :bigint           not null
#
# Indexes
#
#  index_csv_statements_on_payment_method_id  (payment_method_id)
#
# Foreign Keys
#
#  fk_rails_...  (payment_method_id => payment_methods.id)
#
