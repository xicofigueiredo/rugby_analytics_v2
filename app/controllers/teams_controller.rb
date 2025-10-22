class TeamsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_team, only: [:show, :edit, :update, :destroy]
  before_action :require_admin, except: [ :index, :show, :team_profile]


  def index
    if current_user.role == "coach"
      redirect_to team_path(current_user.team)
    end
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

    players = PlayerMatch.joins(:player).where(players: { team_id: @team.id }).where('time_played > 0')

    @forwards_performance_data = calculate_forwards_performance(players)
    @backs_performance_data = calculate_backs_performance(players)
    @team_performance_data = calculate_team_performance(players)

    # Team overall radar chart data (averages from all player ratings)
    @overall_data = calculate_team_rating_averages(@team)
    Rails.logger.info "Team #{@team.name} (ID: #{@team.id}) overall ratings: #{@overall_data.inspect}"

    # Debug: Check if team has any player matches with ratings
    rated_matches_count = PlayerMatch.joins(:player)
                                    .where(players: { team_id: @team.id })
                                    .where('time_played > 0')
                                    .where.not(attack_rating: nil)
                                    .count
    Rails.logger.info "Team #{@team.name} has #{rated_matches_count} player matches with ratings"

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
    # Get all player matches for this team with ratings
    player_matches = PlayerMatch.joins(:player, :match)
                                .where(players: { team_id: team.id })
                                .where('time_played > 0')
                                .where('attack_rating IS NOT NULL OR defense_rating IS NOT NULL OR consistency_rating IS NOT NULL OR discipline_rating IS NOT NULL OR skills_rating IS NOT NULL OR work_rate_rating IS NOT NULL')

    if player_matches.empty?
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

    # Calculate averages across all player performances
    {
      "Attack" => player_matches.average(:attack_rating)&.round(1) || 5.0,
      "Defense" => player_matches.average(:defense_rating)&.round(1) || 5.0,
      "Work Rate" => player_matches.average(:work_rate_rating)&.round(1) || 5.0,
      "Discipline" => player_matches.average(:discipline_rating)&.round(1) || 5.0,
      "Skills" => player_matches.average(:skills_rating)&.round(1) || 5.0,
      "Consistency" => player_matches.average(:consistency_rating)&.round(1) || 5.0
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

  def calculate_team_performance(player_matches)
    # Get team performance data by averaging player ratings per game
    performance_data = {}

    @team.matches.includes(:player_matches, :home_team, :away_team).order(:date).each do |match|
      # Get all player matches for this team in this match with ratings
      team_player_matches = match.player_matches
                                .joins(:player)
                                .where(players: { team_id: @team.id })
                                .where('time_played > 0')
                                .where.not(overall_rating: nil)

      if team_player_matches.any?
        # Calculate average overall rating for the team in this match
        team_ratings = team_player_matches.pluck(:overall_rating).compact
        if team_ratings.any?
          average_rating = (team_ratings.sum / team_ratings.size.to_f).round(1)

          # Show opponent team's name with match date to make it unique
          opponent_team = match.home_team_id == @team.id ? match.away_team : match.home_team
          match_date = match.date ? match.date.strftime("%d/%m") : "Match #{match.id}"
          match_key = "#{opponent_team.name} (#{match_date})"
          performance_data[match_key] = average_rating
        end
      end
    end

    performance_data
  end

  def calculate_forwards_performance(players)
    # Calculate forwards performance data for each match
    performance_data = {}
    forward_positions = ["Loosehead Prop", "Hooker", "Tighthead Prop", "Lock", "Flanker", "Number 8"]

    @team.matches.includes(:player_matches, :home_team, :away_team).order(:date).each do |match|
      # Get forwards who played in this specific match
      match_forwards = match.player_matches
                           .joins(:player)
                           .where(players: { team_id: @team.id })
                           .where('players.positions && ARRAY[?]::varchar[]', forward_positions)
                           .where('time_played > 0')

      # Calculate average overall rating for forwards in this match
      if match_forwards.any?
        ratings = match_forwards.filter_map(&:overall_rating).compact
        if ratings.any?
          average_rating = (ratings.sum / ratings.size.to_f).round(1)

          opponent_team = match.home_team_id == @team.id ? match.away_team : match.home_team
          match_date = match.date ? match.date.strftime("%d/%m") : "Match #{match.id}"
          match_key = "#{opponent_team.name} (#{match_date})"
          performance_data[match_key] = average_rating
        end
      end
    end

    performance_data
  end

  def calculate_backs_performance(players)
    # Calculate backs performance data for each match
    performance_data = {}
    back_positions = ["Scrum-half", "Fly-half", "Wing", "Centre", "Full-back"]

    @team.matches.includes(:player_matches, :home_team, :away_team).order(:date).each do |match|
      # Get backs who played in this specific match
      match_backs = match.player_matches
                        .joins(:player)
                        .where(players: { team_id: @team.id })
                        .where('players.positions && ARRAY[?]::varchar[]', back_positions)
                        .where('time_played > 0')

      # Calculate average overall rating for backs in this match
      if match_backs.any?
        ratings = match_backs.filter_map(&:overall_rating).compact
        if ratings.any?
          average_rating = (ratings.sum / ratings.size.to_f).round(1)

          opponent_team = match.home_team_id == @team.id ? match.away_team : match.home_team
          match_date = match.date ? match.date.strftime("%d/%m") : "Match #{match.id}"
          match_key = "#{opponent_team.name} (#{match_date})"
          performance_data[match_key] = average_rating
        end
      end
    end

    performance_data
  end

end
