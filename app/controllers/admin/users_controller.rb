module Admin
  class UsersController < ApplicationController
    before_action :authenticate_user!
    before_action :set_user, only: [:link_player]

    def index
      @users = User.includes(:team, :player).order(created_at: :desc)
    end

    def link_player
      if @user.update(user_params)
        redirect_to admin_users_path, notice: 'Player was successfully linked.'
      else
        redirect_to admin_users_path, alert: 'Failed to link player.'
      end
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      params.require(:user).permit(:player_id)
    end
  end
end
