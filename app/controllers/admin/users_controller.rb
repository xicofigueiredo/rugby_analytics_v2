module Admin
  class UsersController < ApplicationController
    before_action :authenticate_user!
    before_action :set_user, only: [:show, :edit, :update, :link_player]

    def index
      @users = User.includes(:team, :player)

      # Apply role filter
      if params.dig(:user, :role).present?
        @users = @users.where(role: params[:user][:role])
      end

      # Apply team filter
      if params.dig(:user, :team_id).present?
        @users = @users.where(team_id: params[:user][:team_id])
      end

      # Apply sorting
      @sort_direction = params[:sort_direction] == 'asc' ? 'asc' : 'desc'
      @users = @users.order(created_at: @sort_direction)

      # Handle both Turbo Frame and regular requests
      respond_to do |format|
        format.html
        format.turbo_stream
      end
    end

    def show
      # The @user is already set by before_action :set_user
    end

    def edit
    end

    def update
      if @user.update(user_params)
        redirect_to admin_users_path, notice: 'User was successfully updated.'
      else
        render :edit, status: :unprocessable_entity
      end
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
      params.require(:user).permit(:name, :email, :role, :team_id, :player_id)
    end
  end
end
