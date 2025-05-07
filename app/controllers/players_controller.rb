class PlayersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_player, only: [:show, :edit, :update]

  def index
    @players = Player.all.order(name: :asc)

    if params.dig(:player, :team_id).present?
      @players = @players.where(team_id: params[:player][:team_id])
    end

    if params.dig(:player, :positions)&.reject(&:blank?)&.present?
      @players = @players.where('positions && ARRAY[?]::varchar[]',
        Array(params[:player][:positions]).reject(&:blank?))
    end

    if params.dig(:player, :has_account).present?
      if params[:player][:has_account] == 'true'
        @players = @players.joins(:user)
      else
        @players = @players.left_outer_joins(:user).where(users: { id: nil })
      end
    end

    @players = @players.includes(:team, :user)

    # Handle both Turbo Frame and regular requests
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def new
    @player = Player.new
    @player.team_id = params[:team_id] if params[:team_id].present?
  end

  def create
    @player = Player.new(player_params)
    if @player.save
      redirect_to players_path, notice: 'Player was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
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
    @player = Player.includes(:team, :user).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to players_path, alert: 'Player not found.'
  end

  def player_params
    params.require(:player)
          .permit(:name, :age, :height, :weight, :team_id, :country, positions: [])
          .tap { |params| params[:positions]&.reject!(&:blank?) }
  end
end
