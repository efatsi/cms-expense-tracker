class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :authenticate_user!

  def require_admin!
    redirect_to root_path, alert: "Not authorized." unless current_user&.admin?
  end

  def require_employee!
    redirect_to new_user_session_path unless current_user
  end
end
