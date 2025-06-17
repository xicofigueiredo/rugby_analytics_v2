class MatchesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_match, only: [:show, :edit, :update, :destroy]
  before_action :set_opponents, only: [:new, :edit, :create, :update]
  before_action :require_admin, only: [:new, :create, :edit, :update, :destroy]

  def index
    @matches = Match.all
    @role = current_user.role

    if @role != 'admin'
      @matches = @matches.where("home_team_id = ? OR away_team_id = ?", current_user.team_id, current_user.team_id)
    end

    @current_team = current_user.team if current_user.team

    # Apply team filter
    if params[:team_id].present?
      @matches = @matches.where("home_team_id = ? OR away_team_id = ?", params[:team_id], params[:team_id])
    end

    # Apply season filter
    if params[:season].present?
      @matches = @matches.where(season: params[:season])
    end

    # Apply month filter
    if params[:month].present?
      @matches = @matches.where("EXTRACT(MONTH FROM date) = ?", params[:month])
    end

    # Apply sorting
    @sort_direction = params[:sort_direction] == 'asc' ? 'asc' : 'desc'
    @matches = @matches.order(date: @sort_direction, created_at: @sort_direction)

    # Handle both Turbo Frame and regular requests
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def show
    @players = PlayerMatch.where(match_id: @match.id).map(&:player)
    @home_players = Team.second.players
    @away_players = Team.first.players
    @player_match = PlayerMatch.where(match_id: @match.id, player_id: current_user.player_id).first

    if current_user.role == "player"
      @player = current_user.player

    elsif current_user.role == "coach"
      @player = @match.player_matches.first.player
    end
    @general_stats = [
      { name: "Carries", home: 63, away: 37 },
      { name: "Tackles", home: 50, away: 50 },
      { name: "Turnovers", home: 66, away: 34 },
      { name: "Passes", home: 34, away: 66 },
      { name: "Errors", home: 52, away: 48 },
      { name: "Penalties", home: 62, away: 38 },
      { name: "Cards", home: 50, away: 50 }
    ]

    @setpiece_stats = [
      { name: "Lineouts", home: 64, away: 36 },
      { name: "Lineouts*", home: 60, away: 40 },
      { name: "Mauls", home: 45, away: 55 },
      { name: "Scrums", home: 40, away: 60 },
      { name: "Rucks", home: 85, away: 55 }
    ]

    @negative_stats = [
      { name: "Errors", home: 52, away: 48 },
      { name: "Penalties", home: 62, away: 38 },
      { name: "Cards", home: 0, away: 0 }
    ]

    @home_data = @general_stats.map { |s| [s[:name], s[:home]] }.to_h
    @away_data = @general_stats.map { |s| [s[:name], s[:away]] }.to_h


    @chartkick_data = [
      { name: @match.home_team.name, data: @general_stats.map { |s| [s[:name], s[:home]] } },
      { name: @match.away_team.name, data: @general_stats.map { |s| [s[:name], s[:away]] } }
    ]

    @performance_data = {
      "Tackles" => 5,
      "Turnovers" => 4,
      "Errors" => 7,
      "Penalties" => 8,
      "Cards" => 6,
      "Carries" => 5,
      "Passes" => 8,
      "Scrums" => 3,
      "Mauls" => 4,
      "Lineouts" => 4
    }

    @average_player_performance_data = {
      "Tackles" => 7,
      "Turnovers" => 7,
      "Errors" => 3,
      "Penalties" => 7,
      "Cards" => 7,
      "Carries" => 7,
      "Passes" => 6,
      "Scrums" => 3,
      "Mauls" => 6,
      "Lineouts" => 7
    }

    @minutes_data = {
      "CDUL" => 65,
      "CDUP" => 72,
      "AAC" => 50,
      "Bel" => 78,
      "GDD" => 58
    }

    @player_match_performance_data = {
      "Attack" => 8.3,
      "Defense" => 5.2,
      "Work Rate" => 6.5,
      "Discipline" => 8.1,
      "Kicking" => 5.4,
      "Set Piece" => 5.2,
      "Breakdown" => 6.5
    }

    @player_season_average_performance_data = {
      "Attack" => 7,
      "Defense" => 6,
      "Work Rate" => 7,
      "Discipline" => 2,
      "Kicking" => 6,
      "Set Piece" => 6,
      "Breakdown" => 7
    }

    @stats_dropdown_options = [
      "Tackles",
      "Turnovers",
      "Errors",
      "Penalties",
      "Cards",
      "Carries",
      "Turnovers",
      "Penalties Conceded",
      "Passes"
    ]

    @metrics_dropdown_options = [
      "Tackle Dominance Rate",
      "Tackle Assist Rate",
      "Gain Line Sucess Rate",
      "Carry Effectiveness/ Ratio",
      "Pass Success Rate",
      "Pass Completion Rate",
      "Recovered Kicks",
      "Goal Kick Success Rate",
      "Linebreak per carry/rate",
      "Turnover per minute"
    ]
  end

  def new
    @match = Match.new
    @teams = Team.all
  end

  def create
    @match = Match.new(match_params)
    if @match.save
      redirect_to @match, notice: 'Match was successfully created.'
    else
      @teams = Team.all
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @teams = Team.all
  end

  def update
    if @match.update(match_params)
      redirect_to @match, notice: 'Match was successfully updated.'
    else
      @teams = Team.all
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @match.destroy
    redirect_to matches_url, notice: 'Match was successfully deleted.'
  end

  def player_stats
    @match = Match.find(params[:id])
    @player = Player.find(params[:player_id])
    @player_match = PlayerMatch.where(match_id: @match.id, player_id: @player.id).first

    # Mock data for player stats
    @performance_data = {
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

    # Mock data for team average
    @average_player_performance_data = {
      "Tackles" => 10,
      "Turnovers" => 5,
      "Errors" => 3,
      "Penalties" => 2,
      "Cards" => 0.5,
      "Carries" => 12,
      "Passes" => 20,
      "Scrums" => 5,
      "Mauls" => 6,
      "Lineouts" => 4
    }

    # Mock data for minutes played
    @minutes_data = {
      "Minutes" => rand(40..80)
    }

    # Mock data for performance ratings
    @player_match_performance_data = {
      "Attack" => rand(5.0..9.0).round(1),
      "Defense" => rand(5.0..9.0).round(1),
      "Work Rate" => rand(5.0..9.0).round(1),
      "Discipline" => rand(5.0..9.0).round(1),
      "Kicking" => rand(5.0..9.0).round(1),
      "Set Piece" => rand(5.0..9.0).round(1),
      "Breakdown" => rand(5.0..9.0).round(1)
    }

    # Mock data for season averages
    @player_season_average_performance_data = {
      "Attack" => 7.2,
      "Defense" => 6.8,
      "Work Rate" => 7.5,
      "Discipline" => 6.9,
      "Kicking" => 6.5,
      "Set Piece" => 7.1,
      "Breakdown" => 6.7
    }

    render partial: 'coach_match_stats', locals: { player: @player }
  end

  private

  def set_match
    @match = Match.find(params[:id])
  end

  def set_opponents
    @opponents = Team.where.not(id: current_user.team_id)
  end

  def match_params
    params.require(:match).permit(
      :season,
      :competition,
      :date,
      :home_team_id,
      :away_team_id,
      :result,
      :description,
      player_matches_attributes: [:id, :player_id, :position, :_destroy, :coach_notes, :player_notes]
    )
  end

  def require_admin
    unless current_user.role == 'admin'
      redirect_to matches_path, alert: 'You are not authorized to access this area.'
    end
  end

  def ensure_user_has_team
    unless current_user.team
      redirect_to teams_path, alert: 'You need to be part of a team to create matches.'
    end
  end

  def player_match_params
    params.require(:player_match).permit(
      :coach_notes,
      :player_notes
    )
  end
end
