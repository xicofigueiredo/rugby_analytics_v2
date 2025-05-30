class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [
      :name,
      :team_id,
      :role,
      :age,
      { positions: [] },  # Array field
      :height,
      :weight
    ])
  end

  def after_sign_in_path_for(resource)
    if resource.role == "admin"
      matches_path
    elsif resource.role == "player"
      profile_path
    else
      root_path
    end
  end
end
