class Users::InvitationsController < Devise::InvitationsController
  before_action :require_admin!, only: [ :new, :create ]

  private

  def invite_resource
    resource_class.invite!(invite_params, current_inviter)
  end

  def invite_params
    params.require(:user).permit(:email, :name)
  end
end
