class User < ApplicationRecord
  devise :invitable, :database_authenticatable,
         :recoverable, :rememberable, :validatable

  enum :role, { employee: 0, admin: 1 }, default: :employee

  belongs_to :default_payment_method, class_name: "PaymentMethod", optional: true
  has_many :receipts

  validates :name, presence: true

  def admin?
    role == "admin"
  end

  def employee?
    role == "employee"
  end
end
