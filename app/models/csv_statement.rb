class CsvStatement < ApplicationRecord
  belongs_to :payment_method
  has_one_attached :file
end
