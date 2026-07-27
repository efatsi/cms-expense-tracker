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

# == Schema Information
#
# Table name: users
#
#  id                        :bigint           not null, primary key
#  email                     :string           default(""), not null
#  encrypted_password        :string           default(""), not null
#  invitation_accepted_at    :datetime
#  invitation_created_at     :datetime
#  invitation_limit          :integer
#  invitation_sent_at        :datetime
#  invitation_token          :string
#  invitations_count         :integer          default(0)
#  invited_by_type           :string
#  name                      :string
#  remember_created_at       :datetime
#  reset_password_sent_at    :datetime
#  reset_password_token      :string
#  role                      :integer
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  default_payment_method_id :integer
#  invited_by_id             :bigint
#
# Indexes
#
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_invitation_token      (invitation_token) UNIQUE
#  index_users_on_invited_by            (invited_by_type,invited_by_id)
#  index_users_on_invited_by_id         (invited_by_id)
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#
