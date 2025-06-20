class PlayersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_player, only: [:show, :edit, :update]
  before_action :require_admin, only: [:index,:new, :create]
  before_action :skip_if_not_current_user, only: [:show, :edit, :update]

  def index
    if current_user.role == 'admin'
      @players = Player.all.order(name: :asc)
    else
      @players = Player.where(team_id: current_user.team_id).order(name: :asc)
    end


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
    @performance_data = {
      "CDUL" => 9,
      "CDUP" => 4,
      "AAC" => 7,
      "Bel" => 8,
      "GDD" => 6
    }

    @minutes_data = {
      "CDUL" => 65,
      "CDUP" => 72,
      "AAC" => 50,
      "Bel" => 78,
      "GDD" => 58
    }

    @overall_data = {
      "Attack" => 8,
      "Defense" => 5,
      "Work Rate" => 6,
      "Discipline" => 8,
      "Kicking" => 5,
      "Set Piece" => 5,
      "Breakdown" => 6
    }
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

  def profile
    @player = current_user.player

    # Fetch attack stats per month
    @attack_stats = {
      carries: 14,
      passes: 8
    }

    # Fetch defense stats per month
    @defense_stats = {
      tackles: 37,
      turnovers: 4
    }

    # Fetch kicking stats per month
    @kicking_stats = {
      kicks: 1
    }

    @performance_data = {
      "CDUL" => 9,
      "CDUP" => 4,
      "AAC" => 7,
      "Bel" => 6,
      "GDD" => 8,
      "SLB" => 7
    }

    @player_performance_data = {
      "CDUL" => 6,
      "CDUP" => 7,
      "AAC" => 4,
      "Bel" => 6,
      "GDD" => 7,
      "SLB" => 8
    }

    @group_performance_data = {
      "CDUL" => 8,
      "CDUP" => 4,
      "AAC" => 6,
      "Bel" => 5,
      "GDD" => 9,
      "SLB" => 6
    }

    @overall_data = {
      "Attack" => 8,
      "Defense" => 5,
      "Work Rate" => 6,
      "Discipline" => 8,
      "Kicking" => 5,
      "Set Piece" => 5,
      "Breakdown" => 6
    }
  end

  def all_stats
    @player = Player.find(params[:id])
  end

  def head_to_head
    # Ensure only coaches can access this
    unless current_user.role == 'coach' || current_user.role == 'admin'
      redirect_to root_path, alert: 'Only coaches can access the head-to-head comparison tool.'
    end

    # Get all players from the coach's team with error handling
    if current_user.team.present?
      @team_players = current_user.team.players.order(:name)
    else
      redirect_to root_path, alert: 'You are not assigned to a team. Please contact an administrator.'
    end

    # Get selected players for comparison
    @player1_id = params[:player1_id]
    @player2_id = params[:player2_id]

    if @player1_id.present? && @player2_id.present?
      @player1 = Player.find(@player1_id)
      @player2 = Player.find(@player2_id)

      # Generate mock comparison data for both players
      @player1_stats = {
        "Tackles" => rand(5..15),
        "Turnovers" => rand(2..8),
        "Errors" => rand(1..5),
        "Penalties" => rand(0..3),
        "Cards" => rand(0..1),
        "Carries" => rand(5..20),
        "Passes" => rand(10..30),
        "Scrums" => rand(2..8),
        "Mauls" => rand(3..10),
        "Lineouts" => rand(2..6)
      }

      @player2_stats = {
        "Tackles" => rand(5..15),
        "Turnovers" => rand(2..8),
        "Errors" => rand(1..5),
        "Penalties" => rand(0..3),
        "Cards" => rand(0..1),
        "Carries" => rand(5..20),
        "Passes" => rand(10..30),
        "Scrums" => rand(2..8),
        "Mauls" => rand(3..10),
        "Lineouts" => rand(2..6)
      }

      # Performance ratings for radar chart
      @player1_performance = {
        "Attack" => rand(5.0..9.0).round(1),
        "Defense" => rand(5.0..9.0).round(1),
        "Work Rate" => rand(5.0..9.0).round(1),
        "Discipline" => rand(5.0..9.0).round(1),
        "Kicking" => rand(5.0..9.0).round(1),
        "Set Piece" => rand(5.0..9.0).round(1),
        "Breakdown" => rand(5.0..9.0).round(1)
      }

      @player2_performance = {
        "Attack" => rand(5.0..9.0).round(1),
        "Defense" => rand(5.0..9.0).round(1),
        "Work Rate" => rand(5.0..9.0).round(1),
        "Discipline" => rand(5.0..9.0).round(1),
        "Kicking" => rand(5.0..9.0).round(1),
        "Set Piece" => rand(5.0..9.0).round(1),
        "Breakdown" => rand(5.0..9.0).round(1)
      }

      # Season averages
      @player1_season_avg = {
        "Attack" => 7.2,
        "Defense" => 6.8,
        "Work Rate" => 7.5,
        "Discipline" => 6.9,
        "Kicking" => 6.5,
        "Set Piece" => 7.1,
        "Breakdown" => 6.7
      }

      @player2_season_avg = {
        "Attack" => 6.8,
        "Defense" => 7.2,
        "Work Rate" => 6.9,
        "Discipline" => 7.1,
        "Kicking" => 7.0,
        "Set Piece" => 6.8,
        "Breakdown" => 7.3
      }
    end
  end

  private

  def skip_if_not_current_user
    unless @player == current_user.player || current_user.role == 'admin' || current_user.role == 'coach'
      redirect_to players_path, alert: 'You are not authorized to perform this action.'
    end
  end

  def require_admin
    unless current_user.role == 'admin'
      redirect_to my_team_player_path(current_user.team_id), alert: 'You are not authorized to perform this action.'
    end
  end

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
