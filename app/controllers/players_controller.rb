class PlayersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_player, only: [:show, :edit, :update]

  def index
    @players = User.includes(:team)
                  .where(role: 'player')
                  .order(name: :asc)
  end

  def show
  end

  def edit
  end

  def update
    if @player.update(player_params)
      redirect_to players_path, notice: 'Player was successfully updated.'
    else
      flash.now[:alert] = 'There was an error updating the player.'
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_player
    @player = User.includes(:team)
                 .where(role: 'player')
                 .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to players_path, alert: 'Player not found.'
  end

  def player_params
    params.require(:user)
          .permit(:name, :team_id, :age, :height, :weight, positions: [])
          .tap { |params| params[:positions]&.reject!(&:blank?) }
  end
end
