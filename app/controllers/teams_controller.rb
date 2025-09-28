class TeamsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_team, only: [:show, :edit, :update, :destroy]
  before_action :require_admin, except: [:my_team_player, :team_profile]


  def index
    @teams = Team.all
    @available_levels = Team.distinct.pluck(:level).sort
    @available_countries = Team.distinct.pluck(:country).sort

    # Apply level filter
    if params[:level].present?
      @teams = @teams.where(level: params[:level])
    end

    # Apply country filter

    # Handle both Turbo Frame and regular requests
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def show
    @players = @team.players.order(name: :asc)
  end

  def my_team_player
    @team = current_user.team

    # Format the data as a simple hash like in the player show
    @team_performance_data = {
      "CDUL" => 9,
      "CDUP" => 4,
      "AAC" => 7,
      "Bel" => 8,
      "GDD" => 6
    }

    # # Create hash with team and player data
    # team_data = {
    #   'teams': Team.all.map { |t| t.name },
    #   'players': Team.all.map { |t| t.players.map { |p| p.name } }
    # }

    # # Convert to JSON and pass to Python script
    # command = "python3 hello_world.py '#{team_data.to_json}'"

    # # Execute command and parse the JSON response
    # @output = JSON.parse(`#{command}`)
  end

  def team_profile
    @team = current_user.team
    @players = @team.players.includes(:user)

    # Calculate team averages (mock data for now, similar to player profile)
    # In a real app, you'd calculate these from actual player stats

    # Team performance over time (average of all players)
    @team_performance_data = {
      "CDUL" => 7.2,
      "CDUP" => 6.8,
      "AAC" => 6.5,
      "Bel" => 7.0,
      "GDD" => 6.9,
      "SLB" => 7.1
    }

    # Performance compared to other teams
    @performance_data = {
      "CDUL" => 9,
      "CDUP" => 4,
      "AAC" => 7,
      "Bel" => 8,
      "GDD" => 6,
      "SLB" => 7
    }

    # League average performance
    @league_performance_data = {
      "CDUL" => 6.5,
      "CDUP" => 6.8,
      "AAC" => 6.2,
      "Bel" => 6.9,
      "GDD" => 6.7,
      "SLB" => 6.6
    }

    # Team overall radar chart data (averages)
    @overall_data = {
      "Attack" => 7.2,
      "Defense" => 6.8,
      "Work Rate" => 7.5,
      "Discipline" => 7.1,
      "Kicking" => 5.8,
      "Set Piece" => 7.3,
      "Breakdown" => 6.9
    }

    # Team stats aggregated
    @team_stats = {
      total_players: @players.count,
      active_players: @players.joins(:user).count,
      average_age: @players.average(:age)&.round(1) || 0,
      average_height: @players.average(:height)&.round(1) || 0,
      average_weight: @players.average(:weight)&.round(1) || 0,
      matches_played: 14, # Mock data
      wins: 9,
      losses: 5,
      tries_scored: 42,
      tries_conceded: 28,
      total_points: 156,
      points_conceded: 98
    }
  end

  def new
    @team = Team.new
  end

  def edit
  end

  def create
    @team = Team.new(team_params)

    if @team.save
      redirect_to teams_path, notice: 'Team was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @team.update(team_params)
      redirect_to teams_path, notice: 'Team was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @team.users.exists?
      redirect_to teams_path, alert: 'Cannot delete team with associated players.'
    else
      @team.destroy
      redirect_to teams_path, notice: 'Team was successfully deleted.'
    end
  end

  private

  def require_admin
    unless current_user.role == 'admin'
      redirect_to root_path, alert: 'You are not authorized to access this area.'
    end
  end

  def set_team
    @team = Team.find(params[:id])
  end

  def team_params
    params.require(:team).permit(:name, :level, :classification, :abbreviation, :main_color, :secondary_color)
  end
end
