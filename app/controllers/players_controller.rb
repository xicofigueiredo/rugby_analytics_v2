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
    @player = Player.find(params[:id])

    @player_general_info = {
      minutes_played: @player.player_matches.where(player_id: @player.id).sum(:time_played),
      matches_played: @player.player_matches.where("player_id = ? AND CAST(time_played AS INTEGER) > 0", @player.id).count,
      starting_lineup: @player.player_matches.where(player_id: @player.id, started: true).count,
      tries: @player.player_matches.where(player_id: @player.id).sum(:try),
      try_assists: @player.player_matches.where(player_id: @player.id).sum(:try_assist),
      yellow_cards: @player.player_matches.where(player_id: @player.id).sum(:yellow),
      red_cards: @player.player_matches.where(player_id: @player.id).sum(:red),
      impact_player: @player.player_matches.where("overall_rating > 8").count,
      average_rating: @player.player_matches.where(player_id: @player.id).average(:overall_rating)
    }

    # Calculate team performance per game (using teamstats)
    @performance_data = calculate_team_performance_per_game(@player)

    # Calculate player performance per game (using player_matches)
    @player_performance_data = calculate_player_performance_per_game(@player)

    # Calculate position group performance per game
    @group_performance_data = calculate_position_group_performance_per_game(@player)
    @position_group_name = get_position_group_name(@player)

    @overall_data = calculate_player_rating_averages(@player)
  end

  def edit
  end

  def update
    if @player.update(player_params)
      if current_user.role == 'admin'
        redirect_to players_path, notice: 'Player was successfully updated.'
      elsif current_user.role == 'coach'
        redirect_to team_path(@player.team), notice: 'Player was successfully updated.'
      else
        redirect_to player_path(@player), notice: 'Player was successfully updated.'
      end
    else
      flash.now[:alert] = 'There was an error updating the player.'
      render :edit, status: :unprocessable_entity
    end
  end

  def profile
    @player = current_user.player

    # Get all player matches with time played > 0 for efficiency
    player_matches = @player.player_matches.where("time_played > 0")

    # Use ActiveRecord aggregate methods which handle the SQL properly
    @player_general_info = {
      minutes_played: player_matches.sum(:time_played) || 0,
      matches_played: player_matches.count || 0,
      starting_lineup: player_matches.where(started: true).count || 0,
      tries: player_matches.sum("COALESCE(try, 0)") || 0,
      try_assists: player_matches.sum("COALESCE(try_assist, 0)") || 0,
      yellow_cards: player_matches.sum("COALESCE(yellow, 0)") || 0,
      red_cards: player_matches.sum("COALESCE(red, 0)") || 0,
      impact_player: player_matches.where("overall_rating > 8").count || 0,
      average_rating: player_matches.where.not(overall_rating: nil).average(:overall_rating)&.round(1) || 0
    }

    # Calculate team performance per game (using teamstats)
    @performance_data = calculate_team_performance_per_game(@player)

    # Calculate player performance per game (using player_matches)
    @player_performance_data = calculate_player_performance_per_game(@player)

    # Calculate position group performance per game
    @group_performance_data = calculate_position_group_performance_per_game(@player)
    @position_group_name = get_position_group_name(@player)

    # Calculate radar chart data - use average ratings across all player matches
    if player_matches.any?
      # Always use averages across all matches
      @overall_data = {
        "Attack" => player_matches.where.not(attack_rating: nil).average(:attack_rating)&.round(1) || 0.0,
        "Defense" => player_matches.where.not(defense_rating: nil).average(:defense_rating)&.round(1) || 0.0,
        "Work Rate" => player_matches.where.not(work_rate_rating: nil).average(:work_rate_rating)&.round(1) || 0.0,
        "Discipline" => player_matches.where.not(discipline_rating: nil).average(:discipline_rating)&.round(1) || 0.0,
        "Skills" => player_matches.where.not(skills_rating: nil).average(:skills_rating)&.round(1) || 0.0,
        "Consistency" => player_matches.where.not(consistency_rating: nil).average(:consistency_rating)&.round(1) || 0.0
      }
    else
      @overall_data = {
        "Attack" => 0,
        "Defense" => 0,
        "Work Rate" => 0,
        "Discipline" => 0,
        "Skills" => 0,
        "Consistency" => 0
      }
    end

    Rails.logger.info "Profile radar data for #{@player.name}: #{@overall_data.inspect}"
    Rails.logger.info "Player matches count: #{player_matches.count}"
    if player_matches.any?
      Rails.logger.info "First match ratings: #{player_matches.first.attributes.slice('attack_rating', 'defense_rating', 'work_rate_rating', 'discipline_rating', 'skills_rating', 'consistency_rating')}"
    end
  end

  def all_stats
    @player = Player.find(params[:id])

    # Get filter parameter (CN1, CN2, or All)
    @competition_filter = params[:competition_filter] || 'all'

    # Get all player matches with playing time
    player_matches = @player.player_matches.joins(:match)
                            .where("CAST(time_played AS INTEGER) > 0")

    # Apply competition filter
    if @competition_filter == 'cn1'
      player_matches = player_matches.where("matches.competition ILIKE ?", "%CN1%")
    elsif @competition_filter == 'cn2'
      player_matches = player_matches.where("matches.competition ILIKE ?", "%CN2%")
    end
    # If 'all', no additional filter is applied

    # Calculate all detailed stats using filtered player_matches
    @player_stats = calculate_player_season_stats(@player, player_matches)

    # Calculate total minutes played for per-minute calculations
    @total_minutes = player_matches.sum(:time_played) || 0

    # Calculate per-10-minute rates for each stat
    @per_10min_stats = {}
    @player_stats.each do |stat_name, value|
      if @total_minutes > 0
        per_10min_rate = (value.to_f / @total_minutes * 10).round(1)
        @per_10min_stats[stat_name] = per_10min_rate
      else
        @per_10min_stats[stat_name] = 0
      end
    end
  end

  def head_to_head
    # Get all players from the coach's team with error handling
    if current_user.team.present?
      @team_players = current_user.team.players.order(:name)
    else
      redirect_to root_path, alert: 'You are not assigned to a team. Please contact an administrator.'
    end

    # Get filter parameter (CN1, CN2, or All)
    @competition_filter = params[:competition_filter] || 'all'

    # Get selected players for comparison
    @player1_id = params[:player1_id]
    @player2_id = params[:player2_id]
    @player3_id = params[:player3_id]

    if @player1_id.present? && @player2_id.present?
      @player1 = Player.find(@player1_id)
      @player2 = Player.find(@player2_id)
      @player3 = Player.find(@player3_id) if @player3_id.present?

      # Get filtered player_matches for each player
      player1_matches = filter_player_matches(@player1.player_matches, @competition_filter)
      player2_matches = filter_player_matches(@player2.player_matches, @competition_filter)
      player3_matches = @player3.present? ? filter_player_matches(@player3.player_matches, @competition_filter) : nil

      # Calculate real statistics from filtered player_matches
      @player1_stats = calculate_player_season_stats(@player1, player1_matches)
      @player2_stats = calculate_player_season_stats(@player2, player2_matches)

      # Calculate real statistics for third player if present
      if @player3.present?
        @player3_stats = calculate_player_season_stats(@player3, player3_matches)
      end

      # Performance ratings for radar chart (using filtered matches)
      @player1_performance = calculate_player_rating_averages(@player1, player1_matches)
      @player2_performance = calculate_player_rating_averages(@player2, player2_matches)

      # Performance data for third player if present
      if @player3.present?
        @player3_performance = calculate_player_rating_averages(@player3, player3_matches)
      end

      # Season averages (same as performance for now, could be filtered by season later)
      @player1_season_avg = calculate_player_rating_averages(@player1, player1_matches)
      @player2_season_avg = calculate_player_rating_averages(@player2, player2_matches)

      # Season averages for third player if present
      if @player3.present?
        @player3_season_avg = calculate_player_rating_averages(@player3, player3_matches)
      end
    end
  end

  private

  def filter_player_matches(player_matches, competition_filter)
    # Join with match to filter by competition
    filtered = player_matches.joins(:match)

    # Apply competition filter
    if competition_filter == 'cn1'
      filtered = filtered.where("matches.competition ILIKE ?", "%CN1%")
    elsif competition_filter == 'cn2'
      filtered = filtered.where("matches.competition ILIKE ?", "%CN2%")
    end

    filtered
  end

  def calculate_player_rating_averages(player, player_matches = nil)
    # Get all player matches with ratings (use provided matches or get all)
    if player_matches.nil?
      player_matches = player.player_matches.where.not(
        attack_rating: nil,
        defense_rating: nil,
        consistency_rating: nil,
        discipline_rating: nil,
        skills_rating: nil,
        work_rate_rating: nil
      )
    else
      # Filter the provided matches to only include those with ratings
      player_matches = player_matches.where.not(
        attack_rating: nil,
        defense_rating: nil,
        consistency_rating: nil,
        discipline_rating: nil,
        skills_rating: nil,
        work_rate_rating: nil
      )
    end

    Rails.logger.info "Player #{player.name} has #{player_matches.count} matches with ratings"

    if player_matches.empty?
      # Return default values if no ratings available
      Rails.logger.info "No ratings found for #{player.name}, returning defaults"
      return {
        "Attack" => 0,
        "Defense" => 0,
        "Work Rate" => 0,
        "Discipline" => 0,
        "Skills" => 0,
        "Consistency" => 0
      }
    end

    # Calculate averages
    result = {
      "Attack" => player_matches.average(:attack_rating)&.round(1) || 0.0,
      "Defense" => player_matches.average(:defense_rating)&.round(1) || 0.0,
      "Work Rate" => player_matches.average(:work_rate_rating)&.round(1) || 0.0,
      "Discipline" => player_matches.average(:discipline_rating)&.round(1) || 0.0,
      "Skills" => player_matches.average(:skills_rating)&.round(1) || 0.0,
      "Consistency" => player_matches.average(:consistency_rating)&.round(1) || 0.0
    }

    Rails.logger.info "Calculated ratings for #{player.name}: #{result.inspect}"
    result
  end

  def calculate_player_season_stats(player, player_matches = nil)
    # Get all player_matches for this player where they actually played
    # If player_matches is provided (filtered), use it; otherwise get all matches
    player_matches ||= player.player_matches.where("CAST(time_played AS INTEGER) > 0")

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
        "Game Model +" => 0,

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
        "Game Model -" => 0,

        # Consistency stats
        "Time Played" => 0,
        "Conversions Attempted" => 0,
        "Kicks Attempted" => 0,
        "Drops Attempted" => 0,
        "Lineout Intros Total" => 0,
        "Total Offloads" => 0,
        "Total Aerial Duels" => 0
      }
    end

    # Calculate totals for the season
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
      "Game Model +" => player_matches.sum(:mod_game_plus) || 0,

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
      "Total Penalties" => player_matches.sum { |pm| pm.penalties_conceded },
      "Offside Penalties" => player_matches.sum(:pen_offside) || 0,
      "Ruck Penalties" => player_matches.sum(:pen_breakdown) || 0,
      "Scrum Penalties" => player_matches.sum(:pen_scrum) || 0,
      "Other Penalties" => player_matches.sum(:pen_others) || 0,
      "Yellow Cards" => player_matches.sum(:yellow) || 0,
      "Red Cards" => player_matches.sum(:red) || 0,
      "Knock On" => player_matches.sum(:knock_on) || 0,
      "Other Mistakes" => player_matches.sum(:other_mistakes) || 0,

      # Work Rate stats
      "Total Carries" => (player_matches.sum(:positive_carry) || 0) + (player_matches.sum(:carries) || 0),
      "Total Tackles" => (player_matches.sum(:positive_tackle) || 0) + (player_matches.sum(:neutral_tackle) || 0) + (player_matches.sum(:negative_tackle) || 0) + (player_matches.sum(:assist_tackle) || 0),
      "Game Model -" => player_matches.sum(:mod_game_minus) || 0,

      # Consistency stats
      "Time Played" => player_matches.sum(:time_played) || 0,
      "Conversions Attempted" => (player_matches.sum(:conversion) || 0) + (player_matches.sum(:missed_conversion) || 0),
      "Kicks Attempted" => (player_matches.sum(:penalty_kick_goal) || 0) + (player_matches.sum(:missed_penalty_kick_goals) || 0),
      "Drops Attempted" => (player_matches.sum(:drop_goal) || 0) + (player_matches.sum(:missed_drop_goals) || 0),
      "Lineout Intros Total" => (player_matches.sum(:introduction_won) || 0) + (player_matches.sum(:introduction_lost) || 0),
      "Total Offloads" => (player_matches.sum(:positive_offload) || 0) + (player_matches.sum(:negative_offload) || 0),
      "Total Aerial Duels" => (player_matches.sum(:aerial_duel_won) || 0) + (player_matches.sum(:aerial_duel_lost) || 0)
    }
  end

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
          .permit(:name, :age, :height, :weight, :team_id, :country, :birthdate, :caps, :photo, positions: [])
          .tap { |params| params[:positions]&.reject!(&:blank?) }
  end

  def calculate_team_performance_per_game(player)
    # Get team performance data by averaging player ratings per game
    # Only for matches where the current player played
    performance_data = []

    player.player_matches.includes(match: [:player_matches, :home_team, :away_team]).order('matches.date ASC').each do |player_match|
      # Only include matches where player actually played and has ratings
      if player_match.time_played > 0 && player_match.has_ratings?
        match = player_match.match

        # Get all player matches for this team in this match with ratings
        team_player_matches = match.player_matches
                                  .joins(:player)
                                  .where(players: { team_id: player.team_id })
                                  .where('time_played > 0')
                                  .where.not(overall_rating: nil)

        if team_player_matches.any?
          # Calculate average overall rating for the team in this match
          team_ratings = team_player_matches.pluck(:overall_rating).compact
          if team_ratings.any?
            average_rating = (team_ratings.sum / team_ratings.size.to_f).round(1)

            # Show opponent team's name with match date to make it unique
            opponent_team = match.home_team_id == player.team_id ? match.away_team : match.home_team
            match_date = match.date ? match.date.strftime("%d/%m") : "Match #{match.id}"
            match_key = "#{opponent_team.name} (#{match_date})"
            performance_data << [match_key, average_rating]
          end
        end
      end
    end

    Rails.logger.info "Team performance data: #{performance_data.inspect}"
    performance_data
  end

  def calculate_player_performance_per_game(player)
    # Get player performance data from player_matches per game
    performance_data = []

    player.player_matches.includes(match: [:home_team, :away_team]).order('matches.date ASC').each do |player_match|
      # Only include matches where player actually played and has ratings
      if player_match.time_played > 0 && player_match.has_ratings?
        match = player_match.match

        # Show opponent team's name with match date to make it unique
        opponent_team = match.home_team_id == player.team_id ? match.away_team : match.home_team
        match_date = match.date ? match.date.strftime("%d/%m") : "Match #{match.id}"
        match_key = "#{opponent_team.name} (#{match_date})"
        performance_data << [match_key, player_match.overall_rating]
      end
    end

    performance_data
  end

  def calculate_position_group_performance_per_game(player)
    # Define position groups
    position_groups = {
      "First Row" => ["Loosehead Prop", "Hooker", "Tighthead Prop"],
      "Second Row" => ["Lock"],
      "Back Row" => ["Flanker", "Number 8"],
      "Midfielders" => ["Scrum-half", "Fly-half"],
      "Centers" => ["Centre"],
      "Backline" => ["Wing", "Full-back"]
    }

    # Determine which group the current player belongs to
    player_group = nil
    player.positions.each do |position|
      position_groups.each do |group_name, positions|
        if positions.include?(position)
          player_group = group_name
          break
        end
      end
      break if player_group
    end

    # If no group found, return empty hash
    return {} unless player_group

    # Get all positions in the player's group
    group_positions = position_groups[player_group]

    # Calculate average performance for the position group per game
    # Only for matches where the current player played
    performance_data = []

    player.player_matches.includes(match: [:player_matches, :home_team, :away_team]).order('matches.date ASC').each do |player_match|
      # Only include matches where player actually played and has ratings
      if player_match.time_played > 0 && player_match.has_ratings?
        match = player_match.match

        # Get all players from the same position group who played in this match
        group_players = match.player_matches
                            .joins(:player)
                            .where(players: { team_id: player.team_id })
                            .where('players.positions && ARRAY[?]::varchar[]', group_positions)
                            .where('time_played > 0')

        # Calculate average overall rating for the position group in this match
        if group_players.any?
          ratings = group_players.filter_map(&:overall_rating).compact
          if ratings.any?
            average_rating = (ratings.sum / ratings.size.to_f).round(1)

            opponent_team = match.home_team_id == player.team_id ? match.away_team : match.home_team
            match_date = match.date ? match.date.strftime("%d/%m") : "Match #{match.id}"
            match_key = "#{opponent_team.name} (#{match_date})"
            performance_data << [match_key, average_rating]
          end
        end
      end
    end

    performance_data
  end

  def get_position_group_name(player)
    # Define position groups
    position_groups = {
      "First Row" => ["Loosehead Prop", "Hooker", "Tighthead Prop"],
      "Second Row" => ["Lock"],
      "Back Row" => ["Flanker", "Number 8"],
      "Half-Backs" => ["Scrum-half", "Fly-half"],
      "Centers" => ["Centre"],
      "Backline" => ["Wing", "Full-back"]
    }

    # Find which group the current player belongs to
    player.positions.each do |position|
      position_groups.each do |group_name, positions|
        if positions.include?(position)
          return group_name
        end
      end
    end

    "Position Group" # Default fallback
  end
end
