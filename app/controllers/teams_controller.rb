class TeamsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_team, only: [:show, :edit, :update, :destroy]
  before_action :require_admin, except: [ :team_profile]


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

    # Team overall radar chart data (averages from all teamstats)
    @overall_data = calculate_team_rating_averages(@team)
    Rails.logger.info "Team #{@team.name} overall ratings: #{@overall_data.inspect}"

    # Team stats aggregated
    @team_stats = {
      total_players: @players.count,
      active_users: @players.joins(:user).count,
      average_age: @players.average(:age)&.round(1) || 0,
      average_height: @players.average(:height)&.round(1) || 0,
      average_weight: @players.average(:weight)&.round(1) || 0,
      matches_played: Match.where('home_team_id = ? OR away_team_id = ?', @team.id, @team.id).count,
      wins: Match.where('home_team_id = ? AND result LIKE ?', @team.id, '%-%').count,
      losses: Match.where('away_team_id = ? AND result LIKE ?', @team.id, '%-%').count,
      tries_scored: PlayerMatch.joins(:player).where(players: { team_id: @team.id }).sum(:try),
      total_points: calculate_total_points(@team).first,
      points_conceded: calculate_total_points(@team).second
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

  def calculate_team_rating_averages(team)
    # Get all teamstats for this team with ratings
    teamstats = Teamstat.joins(match: [:home_team, :away_team])
                        .where('matches.home_team_id = ? OR matches.away_team_id = ?', team.id, team.id)
                        .where.not(
                          attack_rating: nil,
                          defense_rating: nil,
                          consistency_rating: nil,
                          discipline_rating: nil,
                          skills_rating: nil,
                          work_rate_rating: nil
                        )

    if teamstats.empty?
      # Return default values if no ratings available
      return {
        "Attack" => 5.0,
        "Defense" => 5.0,
        "Work Rate" => 5.0,
        "Discipline" => 5.0,
        "Skills" => 5.0,
        "Consistency" => 5.0
      }
    end

    # Calculate averages across all matches
    {
      "Attack" => teamstats.average(:attack_rating)&.round(1) || 5.0,
      "Defense" => teamstats.average(:defense_rating)&.round(1) || 5.0,
      "Work Rate" => teamstats.average(:work_rate_rating)&.round(1) || 5.0,
      "Discipline" => teamstats.average(:discipline_rating)&.round(1) || 5.0,
      "Skills" => teamstats.average(:skills_rating)&.round(1) || 5.0,
      "Consistency" => teamstats.average(:consistency_rating)&.round(1) || 5.0
    }
  end

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

  def calculate_total_points(team)
    total_points_scored = 0
    total_points_conceded = 0
    # Get all matches where this team played
    matches = Match.where('home_team_id = ? OR away_team_id = ?', team.id, team.id)

    matches.each do |match|
      next if match.result.blank? || !match.result.include?('-')

      # Split the result by '-' and clean up whitespace
      result_parts = match.result.split('-').map(&:strip)
      next if result_parts.length != 2

      home_points = result_parts[0].to_i
      away_points = result_parts[1].to_i

      # Add points based on whether team was home or away
      if match.home_team_id == team.id
        total_points_scored += home_points
        total_points_conceded += away_points
      elsif match.away_team_id == team.id
        total_points_scored += away_points
        total_points_conceded += home_points
      end
    end

    [total_points_scored, total_points_conceded]
  end

end
