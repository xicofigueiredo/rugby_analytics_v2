require 'csv'

class MatchesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_match, only: [:show, :edit, :update, :destroy]
  before_action :set_opponents, only: [:new, :edit, :create, :update]
  before_action :require_admin, only: [:new, :create, :edit, :update, :destroy, :upload_csv]

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
    @player = current_user.player
    # if current_user.role == "player"
    #   @player = current_user.player

    # elsif current_user.role == "coach"
    #   @player = @match.player_matches.first.player
    # end
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

    if current_user.team.name != "Sport Rugby"
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
    else
      @performance_data = {
        "Tackles" => @player_match.actions.where(action_type: 'tackle').count,
        "Missed Tackles" => @player_match.actions.where(action_type: 'missed_tackle').count,
        "Turnovers" => @player_match.actions.where(action_type: 'turnover').count,
        "Penalties" => @player_match.actions.where(action_type: 'penalty').count,
        "Offloads" => @player_match.actions.where(action_type: 'offload').count,
        "Linebreaks" => @player_match.actions.where(action_type: 'linebreak').count,
        "Knock-ons" => @player_match.actions.where(action_type: 'knock-on').count,
        "Carries" => @player_match.actions.where(action_type: 'carry').count,
        "Cards" => @player_match.actions.where(action_type: 'yellow').count + @player_match.actions.where(action_type: 'red').count,
      }

      @average_player_performance_data = {
        "Tackles" => @match.actions.where(action_type: 'tackle').count/@match.player_matches.count.to_f,
        "Missed Tackles" => @match.actions.where(action_type: 'missed_tackle').count/@match.player_matches.count.to_f,
        "Turnovers" => @match.actions.where(action_type: 'turnover').count/@match.player_matches.count.to_f,
        "Penalties" => @match.actions.where(action_type: 'penalty').count/@match.player_matches.count.to_f,
        "Offloads" => @match.actions.where(action_type: 'offload').count/@match.player_matches.count.to_f,
        "Linebreaks" => @match.actions.where(action_type: 'linebreak').count/@match.player_matches.count.to_f,
        "Knock-ons" => @match.actions.where(action_type: 'knock-on').count/@match.player_matches.count.to_f,
        "Carries" => @match.actions.where(action_type: 'carry').count/@match.player_matches.count.to_f,
        "Cards" => @match.actions.where(action_type: 'yellow').count + @match.actions.where(action_type: 'red').count/@match.player_matches.count.to_f,
      }
    end

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

  def upload_csv
    uploaded_file = params[:csv_file]

    if uploaded_file.nil?
      redirect_to matches_path, alert: 'Please select a CSV file to upload.'
      return
    end

    begin
      csv_data = CSV.read(uploaded_file.path, headers: true)
      process_match_csv(csv_data)
      redirect_to matches_path, notice: 'Match and player stats uploaded successfully!'
    rescue => e
      redirect_to matches_path, alert: "Error processing CSV: #{e.message}"
    end
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

  def process_match_csv(csv_data)
    return if csv_data.empty?

    # Get match data from first row (excluding totals)
    first_row = csv_data.first

    # Extract match information from the row - using correct column names from your CSV
    date_str = first_row['Data']
    home_team_name = first_row['Equipa Casa']
    away_team_name = first_row['Equipa Fora']
    result = first_row['Resultado']
    competition = first_row['Competição']
    season = first_row['Época']

    # Parse date
    date = Date.parse(date_str)

    # Find teams
    home_team = Team.find_by(name: home_team_name&.strip)
    away_team = Team.find_by(name: away_team_name&.strip)

    raise "Home team '#{home_team_name}' not found" unless home_team
    raise "Away team '#{away_team_name}' not found" unless away_team

    # Check if match already exists with same attributes
    existing_match = Match.find_by(
      date: date,
      home_team: home_team,
      away_team: away_team,
      result: result,
      competition: competition,
      season: season
    )

    if existing_match
      raise "Match already exists: #{home_team.name} vs #{away_team.name} on #{date.strftime('%d/%m/%Y')} in #{competition} #{season}"
    end

    # Create match
    match = Match.create!(
      season: season,
      competition: competition,
      date: date,
      home_team: home_team,
      away_team: away_team,
      result: result
    )

    # Process each player row (excluding totals row)
    csv_data.each do |row|
      player_name = row['NOME']

      # Skip totals row or empty names
      next if player_name.blank? || player_name.include?('TOTAL') || player_name.include?('vs')

      # Find player by name
      player = Player.find_by(name: player_name)

      if player.nil?
        Rails.logger.warn "Player '#{player_name}' not found, skipping..."
        next
      end

      # Create player match
      player_match = match.player_matches.create!(player: player)

      # Create actions based on stats
      create_actions_from_stats(player_match, row, csv_data.headers)
    end
  end

  def create_actions_from_stats(player_match, row, headers)
    # Map CSV columns to action types based on your actual CSV format
    action_mapping = {
      'ENSAIOS' => 'try',
      'ASSISTÊNCIA' => 'assist',
      'PLACAGENS' => 'tackle',
      'PLAC. FALHADAS' => 'missed_tackle',
      'RECUPERAÇÃO  AL' => 'lineout_turnover',
      'TURNOVERS' => 'turnover',
      'PENALIDADES' => 'penalty',
      'OFFLOADS' => 'offload',
      'Q. LINHA' => 'linebreak',
      'CARRIES' => 'carry',
      'AMARELO' => 'yellow',
      'VERMELHO' => 'red'
    }

    action_mapping.each do |csv_column, action_type|
      # Try to find the column by name
      value = row[csv_column]

      next if value.blank? || value.to_i <= 0

      # Create the specified number of actions
      value.to_i.times do
        player_match.actions.create!(action_type: action_type)
      end
    end
  end
end
