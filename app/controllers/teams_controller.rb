class TeamsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_team, only: [:show, :edit, :update, :destroy]
  before_action :require_admin, except: [ :index, :show, :team_profile, :all_stats]


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

    # Filter by search term if present
    if params[:search].present?
      @players = @players.where("LOWER(name) LIKE ?", "%#{params[:search].downcase}%")
    end
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
    team_matches = Match.where('home_team_id = ? OR away_team_id = ?', @team.id, @team.id).where.not(result: [nil, ''])
    wins = 0
    losses = 0

    team_matches.each do |match|
      next unless match.result.present? && match.result.include?('-')

      home_score, away_score = match.result.split('-').map(&:to_i)

      if match.home_team_id == @team.id
        # Team is home team
        wins += 1 if home_score > away_score
        losses += 1 if home_score < away_score
      else
        # Team is away team
        wins += 1 if away_score > home_score
        losses += 1 if away_score < home_score
      end
    end

    @team_stats = {
      total_players: @players.count,
      active_users: @players.joins(:user).count,
      average_age: @players.average(:age)&.round(1) || 0,
      average_height: @players.average(:height)&.round(1) || 0,
      average_weight: @players.average(:weight)&.round(1) || 0,
      matches_played: team_matches.count,
      wins: wins,
      losses: losses,
      tries_scored: PlayerMatch.joins(:player).where(players: { team_id: @team.id }).sum(:try),
      total_points: calculate_total_points(@team).first,
      points_conceded: calculate_total_points(@team).second
    }
  end

  def all_stats
    @team = current_user.team
    @players = @team.players.includes(:user)

    # Get all player matches for this team with playing time
    team_player_matches = PlayerMatch.joins(:player)
                                    .where(players: { team_id: @team.id })
                                    .where('time_played > 0')

    # Calculate comprehensive team stats using the same method as individual players
    @team_stats = calculate_team_season_stats(team_player_matches)

    # Calculate total minutes played for per-minute calculations
    @total_minutes = team_player_matches.sum(:time_played) || 0

    # Calculate per-10-minute rates for each stat
    @per_10min_stats = {}
    @team_stats.each do |stat_name, value|
      if @total_minutes > 0
        per_10min_rate = (value.to_f / @total_minutes * 10).round(1)
        @per_10min_stats[stat_name] = per_10min_rate
      else
        @per_10min_stats[stat_name] = 0
      end
    end

    # Get match count for this team
    @matches_played = Match.where('home_team_id = ? OR away_team_id = ?', @team.id, @team.id).count
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
        "Attack" => 0,
        "Defense" => 0,
        "Work Rate" => 0,
        "Discipline" => 0,
        "Skills" => 0,
        "Consistency" => 0
      }
    end

    # Calculate averages across all player performances
    {
      "Attack" => player_matches.average(:attack_rating)&.round(1) || 0.0,
      "Defense" => player_matches.average(:defense_rating)&.round(1) || 0.0,
      "Work Rate" => player_matches.average(:work_rate_rating)&.round(1) || 0.0,
      "Discipline" => player_matches.average(:discipline_rating)&.round(1) || 0.0,
      "Skills" => player_matches.average(:skills_rating)&.round(1) || 0.0,
      "Consistency" => player_matches.average(:consistency_rating)&.round(1) || 0.0
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
    performance_data = []

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
          performance_data << [match_key, average_rating]
        end
      end
    end

    performance_data
  end

  def calculate_forwards_performance(players)
    # Calculate forwards performance data for each match
    performance_data = []
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
          performance_data << [match_key, average_rating]
        end
      end
    end

    performance_data
  end

  def calculate_backs_performance(players)
    # Calculate backs performance data for each match
    performance_data = []
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
          performance_data << [match_key, average_rating]
        end
      end
    end

    performance_data
  end

  def calculate_team_season_stats(player_matches)
    if player_matches.empty?
      return {
        # Attack stats
        "Tries" => 0,
        "Assists" => 0,
        "Linebreak" => 0,
        "Linebreak Assists" => 0,
        "Carries With Gain" => 0,
        "Carries Without Gain" => 0,
        "Conversions Made" => 0,
        "Conversions Missed" => 0,
        "Kicks Made" => 0,
        "Kicks Missed" => 0,
        "Drops Made" => 0,
        "Drops Missed" => 0,
        "Mod Game Plus" => 0,

        # Defense stats
        "Positive Tackles" => 0,
        "Neutral Tackles" => 0,
        "Negative Tackles" => 0,
        "Assist Tackles" => 0,
        "Missed Tackles" => 0,
        "Turnovers Won" => 0,
        "Lineout Steals" => 0,
        "Aerial Duels Won" => 0,
        "Aerial Duels Lost" => 0,

        # Skills stats
        "Offloads Good" => 0,
        "Offloads Bad" => 0,
        "Lineouts w/ Jump" => 0,
        "Lineouts w/o Jump" => 0,
        "Lineout Intros Won" => 0,
        "Lineout Intros Lost" => 0,
        "Scrum Dominant" => 0,

        # Discipline stats
        "Total Penalties" => 0,
        "Offside Penalties" => 0,
        "Ruck Penalties" => 0,
        "Scrum Penalties" => 0,
        "Other Penalties" => 0,
        "Yellow Cards" => 0,
        "Red Cards" => 0,
        "Knock On" => 0,
        "Other Mistakes" => 0,

        # Work Rate stats
        "Total Carries" => 0,
        "Total Tackles" => 0,
        "Mod Game Minus" => 0,

        # Consistency stats
        "Time Played" => 0,
        "Conversions Attempted" => 0,
        "Kicks Attempted" => 0,
        "Drops Attempted" => 0,
        "Lineout Intros Total" => 0,
        "Total Offloads" => 0,
        "Total Aerial Duels" => 0,
        "Total Mod Game" => 0
      }
    end

    # Calculate totals for the team across all players
    {
      # Attack stats
      "Tries" => player_matches.sum(:try) || 0,
      "Assists" => player_matches.sum(:try_assist) || 0,
      "Linebreak" => player_matches.sum(:linebreak) || 0,
      "Linebreak Assists" => player_matches.sum(:linebreak_assists) || 0,
      "Carries With Gain" => player_matches.sum(:positive_carry) || 0,
      "Carries Without Gain" => player_matches.sum(:carries) || 0,
      "Conversions Made" => player_matches.sum(:conversion) || 0,
      "Conversions Missed" => player_matches.sum(:missed_conversion) || 0,
      "Kicks Made" => player_matches.sum(:penalty_kick_goal) || 0,
      "Kicks Missed" => player_matches.sum(:missed_penalty_kick_goals) || 0,
      "Drops Made" => player_matches.sum(:drop_goal) || 0,
      "Drops Missed" => player_matches.sum(:missed_drop_goals) || 0,
      "Mod Game Plus" => player_matches.sum(:mod_game_plus) || 0,

      # Defense stats
      "Positive Tackles" => player_matches.sum(:positive_tackle) || 0,
      "Neutral Tackles" => player_matches.sum(:neutral_tackle) || 0,
      "Negative Tackles" => player_matches.sum(:negative_tackle) || 0,
      "Assist Tackles" => player_matches.sum(:assist_tackle) || 0,
      "Missed Tackles" => player_matches.sum(:missed_tackle) || 0,
      "Turnovers Won" => player_matches.sum(:turnover) || 0,
      "Lineout Steals" => player_matches.sum(:lineout_turnover) || 0,
      "Aerial Duels Won" => player_matches.sum(:aerial_duel_won) || 0,
      "Aerial Duels Lost" => player_matches.sum(:aerial_duel_lost) || 0,

      # Skills stats
      "Offloads Good" => player_matches.sum(:positive_offload) || 0,
      "Offloads Bad" => player_matches.sum(:negative_offload) || 0,
      "Lineouts w/ Jump" => player_matches.sum(:lineout_won_jump) || 0,
      "Lineouts w/o Jump" => player_matches.sum(:lineout_won_no_jump) || 0,
      "Lineout Intros Won" => player_matches.sum(:introduction_won) || 0,
      "Lineout Intros Lost" => player_matches.sum(:introduction_lost) || 0,
      "Scrum Dominant" => player_matches.sum(:scrum_dominant) || 0,

      # Discipline stats
      "Total Penalties" => (player_matches.sum(:pen_offside) || 0) + (player_matches.sum(:pen_breakdown) || 0) + (player_matches.sum(:pen_scrum) || 0) + (player_matches.sum(:pen_others) || 0),
      "Offside Penalties" => player_matches.sum(:pen_offside) || 0,
      "Ruck Penalties" => player_matches.sum(:pen_breakdown) || 0,
      "Scrum Penalties" => player_matches.sum(:pen_scrum) || 0,
      "Other Penalties" => player_matches.sum(:pen_others) || 0,
      "Yellow Cards" => player_matches.sum(:yellow) || 0,
      "Red Cards" => player_matches.sum(:red) || 0,
      "Knock On" => player_matches.sum(:knock_on) || 0,
      "Other Mistakes" => player_matches.sum(:other_mistakes) || 0,

      # Work Rate stats
      "Total Carries" => player_matches.sum(:carries) || 0,
      "Total Tackles" => (player_matches.sum(:positive_tackle) || 0) + (player_matches.sum(:neutral_tackle) || 0) + (player_matches.sum(:negative_tackle) || 0) + (player_matches.sum(:assist_tackle) || 0),
      "Mod Game Minus" => player_matches.sum(:mod_game_minus) || 0,

      # Consistency stats
      "Time Played" => player_matches.sum(:time_played) || 0,
      "Conversions Attempted" => (player_matches.sum(:conversion) || 0) + (player_matches.sum(:missed_conversion) || 0),
      "Kicks Attempted" => (player_matches.sum(:penalty_kick_goal) || 0) + (player_matches.sum(:missed_penalty_kick_goals) || 0),
      "Drops Attempted" => (player_matches.sum(:drop_goal) || 0) + (player_matches.sum(:missed_drop_goals) || 0),
      "Lineout Intros Total" => (player_matches.sum(:introduction_won) || 0) + (player_matches.sum(:introduction_lost) || 0),
      "Total Offloads" => (player_matches.sum(:positive_offload) || 0) + (player_matches.sum(:negative_offload) || 0),
      "Total Aerial Duels" => (player_matches.sum(:aerial_duel_won) || 0) + (player_matches.sum(:aerial_duel_lost) || 0),
      "Total Mod Game" => (player_matches.sum(:mod_game_plus) || 0) + (player_matches.sum(:mod_game_minus) || 0)
    }
  end

end
