require 'csv'

class MatchesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_match, only: [:show, :edit, :update, :destroy, :player_data]
  before_action :set_opponents, only: [:new, :edit, :create, :update]
  before_action :require_admin_or_coach, only: [:new, :create, :edit, :update, :destroy, :upload_csv]

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
    @team = current_user.team
    @players = PlayerMatch.where(match_id: @match.id).order(position: :asc)
    @starting_players = @players.where(started: true)
    @bench_players = @players.where(started: false)
    @scorer_players = @players.where("try > 0 OR conversion > 0 OR penalty_kick_goal > 0 OR drop_goal > 0")
    # Set player match based on user role and context
    Rails.logger.info "Current user role: #{current_user.role}, player_id: #{current_user.player_id}, team_id: #{current_user.team_id}"

    if current_user.role == "player" && current_user.player_id.present?
      @player_match = PlayerMatch.where(match_id: @match.id, player_id: current_user.player_id).first
      @player = current_user.player
      Rails.logger.info "Player mode: Found player_match for player_id #{current_user.player_id}: #{@player_match&.id}"
    elsif current_user.role == "coach" || current_user.role == "admin"
      # For coaches/admins, allow viewing specific player via player_match_id parameter
      if params[:player_match_id].present?
        @player_match = PlayerMatch.joins(:player)
                                  .where(id: params[:player_match_id], match_id: @match.id)
                                  .where(players: { team_id: current_user.team_id })
                                  .first
      elsif params[:player_id].present?
        @player_match = PlayerMatch.joins(:player)
                                  .where(match_id: @match.id, player_id: params[:player_id])
                                  .where(players: { team_id: current_user.team_id })
                                  .first
      else
        @player_match = PlayerMatch.joins(:player)
                                  .where(match_id: @match.id)
                                  .where(players: { team_id: current_user.team_id })
                                  .where("time_played > 0")
                                  .first
      end
      @player = @player_match&.player
      Rails.logger.info "Coach/Admin mode: Found player_match for team #{current_user.team_id}: #{@player_match&.id}, player: #{@player&.name}"
    else
      @player_match = nil
      @player = nil
      Rails.logger.info "No valid role or player_id found"
    end
    @staff = @team.users.where.not(role: ["player", "fan"])
    calculate_top_players(@match)

    # if current_user.role == "player"
    #   @player = current_user.player

    # elsif current_user.role == "coach"
    #   @player = @match.player_matches.first.player
    # end


    lineouts_won = @match.teamstat.first.lineouts_won
    lineouts_lost = @match.teamstat.first.lineouts_lost
    lineouts_total = lineouts_won + lineouts_lost
    lineouts_percentage = lineouts_total > 0 ? (lineouts_won.to_f / lineouts_total * 100).round : 0

    lineouts_stolen = @match.teamstat.first.lineouts_stolen
    lineouts_not_stolen = @match.teamstat.first.lineouts_not_stolen
    lineouts_stolen_total = lineouts_stolen + lineouts_not_stolen
    lineouts_stolen_percentage = lineouts_stolen_total > 0 ? (lineouts_stolen.to_f / lineouts_stolen_total * 100).round : 0

    scrums_won = @match.teamstat.first.scrums_won
    scrums_lost = @match.teamstat.first.scrums_lost
    scrums_total = scrums_won + scrums_lost
    scrums_percentage = scrums_total > 0 ? (scrums_won.to_f / scrums_total * 100).round : 0

    scrums_stolen = @match.teamstat.first.scrums_stolen
    scrums_not_stolen = @match.teamstat.first.scrums_not_stolen
    scrums_stolen_total = scrums_stolen + scrums_not_stolen
    scrums_stolen_percentage = scrums_stolen_total > 0 ? (scrums_stolen.to_f / scrums_stolen_total * 100).round : 0

    # Determine which team the stats belong to and who was home/away
    stats_team_id = @match.teamstat.first.team_id
    user_team_id = current_user.team_id
    home_team_id = @match.home_team_id

    # Check if user's team was playing at home or away
    user_team_is_home = (user_team_id == home_team_id)
    user_team_has_stats = (user_team_id == stats_team_id)

    if user_team_has_stats
      # We have stats for user's team - show from their perspective
      if user_team_is_home
        # User's team is home (left side)
        @setpiece_stats = [
          { name: "Lineouts Won (#{lineouts_percentage}%)", home: lineouts_won, away: lineouts_lost, bar_home: lineouts_percentage, bar_away: 100 - lineouts_percentage, percent: false },
          { name: "Lineouts Stolen (#{lineouts_stolen_percentage}%)", home: lineouts_stolen, away: lineouts_not_stolen, bar_home: lineouts_stolen_percentage, bar_away: 100 - lineouts_stolen_percentage, percent: false },
          { name: "Scrums Won (#{scrums_percentage}%)", home: scrums_won, away: scrums_lost, bar_home: scrums_percentage, bar_away: 100 - scrums_percentage, percent: false },
          { name: "Scrums Stolen (#{scrums_stolen_percentage}%)", home: scrums_stolen, away: scrums_not_stolen, bar_home: scrums_stolen_percentage, bar_away: 100 - scrums_stolen_percentage, percent: false }
        ]
      else
        # User's team is away (right side) - flip the data
        @setpiece_stats = [
          { name: "Lineouts Won (#{lineouts_percentage}%)", home: lineouts_lost, away: lineouts_won, bar_home: 100 - lineouts_percentage, bar_away: lineouts_percentage, percent: false },
          { name: "Lineouts Stolen (#{lineouts_stolen_percentage}%)", home: lineouts_not_stolen, away: lineouts_stolen, bar_home: 100 - lineouts_stolen_percentage, bar_away: lineouts_stolen_percentage, percent: false },
          { name: "Scrums Won (#{scrums_percentage}%)", home: scrums_lost, away: scrums_won, bar_home: 100 - scrums_percentage, bar_away: scrums_percentage, percent: false },
          { name: "Scrums Stolen (#{scrums_stolen_percentage}%)", home: scrums_not_stolen, away: scrums_stolen, bar_home: 100 - scrums_stolen_percentage, bar_away: scrums_stolen_percentage, percent: false }
        ]
      end
    else
      # We have stats for opponent - show from opponent's perspective, but display from user's team position
      opponent_lineouts_percentage = lineouts_total > 0 ? 100 - lineouts_percentage : 0
      opponent_lineouts_stolen_percentage = lineouts_stolen_total > 0 ? 100 - lineouts_stolen_percentage : 0
      opponent_scrums_percentage = scrums_total > 0 ? 100 - scrums_percentage : 0
      opponent_scrums_stolen_percentage = scrums_stolen_total > 0 ? 100 - scrums_stolen_percentage : 0

      if user_team_is_home
        # User's team is home (left side), opponent has the stats
        @setpiece_stats = [
          { name: "Lineouts Won (#{opponent_lineouts_percentage}%)", home: lineouts_lost, away: lineouts_won, bar_home: opponent_lineouts_percentage, bar_away: lineouts_percentage, percent: false },
          { name: "Lineouts Stolen (#{opponent_lineouts_stolen_percentage}%)", home: lineouts_not_stolen, away: lineouts_stolen, bar_home: opponent_lineouts_stolen_percentage, bar_away: lineouts_stolen_percentage, percent: false },
          { name: "Scrums Won (#{opponent_scrums_percentage}%)", home: scrums_lost, away: scrums_won, bar_home: opponent_scrums_percentage, bar_away: scrums_percentage, percent: false },
          { name: "Scrums Stolen (#{opponent_scrums_stolen_percentage}%)", home: scrums_not_stolen, away: scrums_stolen, bar_home: opponent_scrums_stolen_percentage, bar_away: scrums_stolen_percentage, percent: false }
        ]
      else
        # User's team is away (right side), opponent has the stats
        @setpiece_stats = [
          { name: "Lineouts Won (#{opponent_lineouts_percentage}%)", home: lineouts_won, away: lineouts_lost, bar_home: lineouts_percentage, bar_away: opponent_lineouts_percentage, percent: false },
          { name: "Lineouts Stolen (#{opponent_lineouts_stolen_percentage}%)", home: lineouts_stolen, away: lineouts_not_stolen, bar_home: lineouts_stolen_percentage, bar_away: opponent_lineouts_stolen_percentage, percent: false },
          { name: "Scrums Won (#{opponent_scrums_percentage}%)", home: scrums_won, away: scrums_lost, bar_home: scrums_percentage, bar_away: opponent_scrums_percentage, percent: false },
          { name: "Scrums Stolen (#{opponent_scrums_stolen_percentage}%)", home: scrums_stolen, away: scrums_not_stolen, bar_home: scrums_stolen_percentage, bar_away: opponent_scrums_stolen_percentage, percent: false }
        ]
      end
    end



      if current_user.role == "coach"
        @performance_data = {}
        @player_match_performance_data = {
          "Attack" => 5.0,
          "Defense" => 5.0,
          "Work Rate" => 5.0,
          "Discipline" => 5.0,
          "Skills" => 5.0,
          "Consistency" => 5.0
        }
        @average_player_performance_data = {
          "Tackles Made" => @match.avg_tackles_made,
          "Missed Tackles" => @match.avg_missed_tackle,
          "Turnovers" => @match.avg_turnover,
          "Penalties" => @match.avg_penalties_conceded,
          "Positive Offloads" => @match.avg_positive_offload,
          "Negative Offloads" => @match.avg_negative_offload,
          "Linebreaks" => @match.avg_linebreak,
          "Knock-ons" => @match.avg_knock_on,
          "Positive Carries" => @match.avg_positive_carry,
        }

        # Set team average performance data for radar chart
        @player_season_average_performance_data = {
          "Attack" => 5.0,
          "Defense" => 5.0,
          "Work Rate" => 5.0,
          "Discipline" => 5.0,
          "Skills" => 5.0,
          "Consistency" => 5.0
        }
      else
        if @player_match
          @performance_data = {
            "Tackles Made" => 0 + @player_match.tackles_made,
            "Missed Tackles" => @player_match.missed_tackle,
            "Turnovers" => @player_match.turnover || 0,
            "Penalties" => @player_match.penalties_conceded || 0,
            "Positive Offloads" => @player_match.positive_offload || 0,
            "Negative Offloads" => @player_match.negative_offload || 0,
            "Linebreaks" => @player_match.linebreak || 0,
            "Knock-ons" => @player_match.knock_on || 0,
            "Positive Carries" => @player_match.positive_carry || 0,
          }

          @player_match_performance_data = {
            "Attack" => @player_match.attack_rating || 5.0,
            "Defense" => @player_match.defense_rating || 5.0,
            "Work Rate" => @player_match.work_rate_rating || 5.0,
            "Discipline" => @player_match.discipline_rating || 5.0,
            "Skills" => @player_match.skills_rating || 5.0,
            "Consistency" => @player_match.consistency_rating || 5.0
          }
        else
          @performance_data = { }
          @player_match_performance_data = { }
        end

        @average_player_performance_data = {
          "Tackles Made" => @match.avg_tackles_made,
          "Missed Tackles" => @match.avg_missed_tackle,
          "Turnovers" => @match.avg_turnover,
          "Penalties" => @match.avg_penalties_conceded,
          "Positive Offloads" => @match.avg_positive_offload,
          "Negative Offloads" => @match.avg_negative_offload,
          "Linebreaks" => @match.avg_linebreak,
          "Knock-ons" => @match.avg_knock_on,
          "Positive Carries" => @match.avg_positive_carry,
        }


        # Calculate team average ratings for this match
        @player_season_average_performance_data = calculate_team_average_ratings(@match, current_user.team_id)

        # Create stats data for JavaScript
        @stats_data = {
          "positive_tackles" => (@positive_tackles_top_players || []).map { |pm| { name: pm.player.name, value: pm.positive_tackle || 0 } },
          "turnovers" => (@turnovers_top_players || []).map { |pm| { name: pm.player.name, value: pm.turnover || 0 } },
          "penalties" => (@penalties_top_players || []).map { |pm| { name: pm.player.name, value: pm.total_penalties || 0 } },
          "carries" => (@carries_top_players || []).map { |pm| { name: pm.player.name, value: pm.carries || 0 } },
          "positive_carries" => (@positive_carries_top_players || []).map { |pm| { name: pm.player.name, value: pm.positive_carry || 0 } },
          "positive_offloads" => (@positive_offloads_top_players || []).map { |pm| { name: pm.player.name, value: pm.positive_offload || 0 } },
          "linebreaks" => (@linebreaks_top_players || []).map { |pm| { name: pm.player.name, value: pm.linebreak || 0 } }
        }
      end

    @minutes_data = {
      "CDUL" => 65,
      "CDUP" => 72,
      "AAC" => 50,
      "Bel" => 78,
      "GDD" => 58
    }

    # Set up player match performance data for all teams
    if @player_match
      @player_match_performance_data = {
        "Attack" => @player_match.attack_rating || 5.0,
        "Defense" => @player_match.defense_rating || 5.0,
        "Work Rate" => @player_match.work_rate_rating || 5.0,
        "Discipline" => @player_match.discipline_rating || 5.0,
        "Skills" => @player_match.skills_rating || 5.0,
        "Consistency" => @player_match.consistency_rating || 5.0
      }
    else
      @player_match_performance_data = {
        "Attack" => 5.0,
        "Defense" => 5.0,
        "Work Rate" => 5.0,
        "Discipline" => 5.0,
        "Skills" => 5.0,
        "Consistency" => 5.0
      }
    end

    # Calculate team average ratings for this match
    @player_season_average_performance_data = calculate_team_average_ratings(@match, current_user.team_id)

    # Calculate best and worst performance metrics
    if @player_match
      calculate_best_worst_metrics(@player_match, @match, current_user.team_id)
    end

    # Fetch raw database values for radar chart
    if @player_match
      @radar_player_data = {
        attack: @player_match.attack_rating || 0,
        defense: @player_match.defense_rating || 0,
        discipline: @player_match.discipline_rating || 0,
        work_rate: @player_match.work_rate_rating || 0,
        skills: @player_match.skills_rating || 0,
        consistency: @player_match.consistency_rating || 0
      }

      # Store overall rating for display
      @player_overall_rating = @player_match.overall_rating || 0

      # Calculate team averages for radar chart
      team_players = PlayerMatch.joins(:player)
                               .where(match_id: @match.id)
                               .where(players: { team_id: current_user.team_id })
                               .where("time_played > 0")

      @radar_team_data = {
        attack: team_players.where.not(attack_rating: nil).average(:attack_rating)&.round(1) || 0,
        defense: team_players.where.not(defense_rating: nil).average(:defense_rating)&.round(1) || 0,
        discipline: team_players.where.not(discipline_rating: nil).average(:discipline_rating)&.round(1) || 0,
        work_rate: team_players.where.not(work_rate_rating: nil).average(:work_rate_rating)&.round(1) || 0,
        skills: team_players.where.not(skills_rating: nil).average(:skills_rating)&.round(1) || 0,
        consistency: team_players.where.not(consistency_rating: nil).average(:consistency_rating)&.round(1) || 0
      }

      # Calculate team average overall rating
      @team_overall_rating = team_players.where.not(overall_rating: nil).average(:overall_rating)&.round(1) || 0
    else
      @radar_player_data = {
        attack: 0, defense: 0, discipline: 0, work_rate: 0, skills: 0, consistency: 0
      }
      @radar_team_data = {
        attack: 0, defense: 0, discipline: 0, work_rate: 0, skills: 0, consistency: 0
      }
      @player_overall_rating = 0
      @team_overall_rating = 0
    end

    @stats_dropdown_options = [
      ["Positive Tackles", "positive_tackles"],
      ["Turnovers", "turnovers"],
      ["Penalties", "penalties"],
      ["Carries", "carries"],
      ["Positive Carries", "positive_carries"],
      ["Positive Offloads", "positive_offloads"],
      ["Linebreaks", "linebreaks"]
    ]

    # Create a hash for JavaScript access
    @stats_data = {
      "positive_tackles" => (@positive_tackles_top_players || []).map { |pm| { name: pm.player.name, value: pm.positive_tackle || 0 } },
      "turnovers" => (@turnovers_top_players || []).map { |pm| { name: pm.player.name, value: pm.turnover || 0 } },
      "penalties" => (@penalties_top_players || []).map { |pm| { name: pm.player.name, value: pm.total_penalties || 0 } },
      "carries" => (@carries_top_players || []).map { |pm| { name: pm.player.name, value: pm.carries || 0 } },
      "positive_carries" => (@positive_carries_top_players || []).map { |pm| { name: pm.player.name, value: pm.positive_carry || 0 } },
      "positive_offloads" => (@positive_offloads_top_players || []).map { |pm| { name: pm.player.name, value: pm.positive_offload || 0 } },
      "linebreaks" => (@linebreaks_top_players || []).map { |pm| { name: pm.player.name, value: pm.linebreak || 0 } }
    }

    Rails.logger.info "Stats data: #{@stats_data.inspect}"

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
      respond_to do |format|
        format.html { redirect_to @match, notice: 'Match was successfully updated.' }
        format.json { render json: { status: 'success', message: 'Match was successfully updated.' } }
      end
    else
      respond_to do |format|
        format.html do
          @teams = Team.all
          render :edit, status: :unprocessable_entity
        end
        format.json { render json: { status: 'error', errors: @match.errors.full_messages } }
      end
    end
  end

  def destroy
    @match.destroy
    redirect_to matches_url, notice: 'Match was successfully deleted.'
  end


  def update_player_match
    @match = Match.find(params[:id])
    @player_match = @match.player_matches.find(params[:player_match_id])

    if @player_match.update(player_match_params)
      respond_to do |format|
        format.json { render json: { status: 'success', message: 'Player notes updated successfully.' } }
      end
    else
      respond_to do |format|
        format.json { render json: { status: 'error', errors: @player_match.errors.full_messages } }
      end
    end
  end

  def upload_csv
    Rails.logger.info "CSV upload started"
    uploaded_file = params[:csv_file]

    if uploaded_file.nil?
      Rails.logger.warn "No CSV file provided"
      redirect_to matches_path, alert: 'Please select a CSV file to upload.'
      return
    end

    Rails.logger.info "CSV file received: #{uploaded_file.original_filename}"
    begin
      # Read CSV with comma delimiter (default)
      csv_data = CSV.read(uploaded_file.path, headers: true)
      Rails.logger.info "CSV read successfully, rows: #{csv_data.count}"
      process_match_csv(csv_data)
      redirect_to matches_path, notice: 'Match and player stats uploaded successfully!'
    rescue => e
      Rails.logger.error "CSV processing error: #{e.class}: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.first(10).join("\n")}"

      # Ensure any failed transaction is properly rolled back
      begin
        if ActiveRecord::Base.connection.transaction_open?
          Rails.logger.info "Rolling back open transaction"
          ActiveRecord::Base.connection.rollback_db_transaction
        end
      rescue => rollback_error
        Rails.logger.error "Error during transaction rollback: #{rollback_error.message}"
        # Reset the connection to ensure it's in a clean state
        ActiveRecord::Base.connection.reconnect!
      end

      redirect_to matches_path, alert: "Error processing CSV: #{e.message}"
    end
  end

  def player_data
    # Find the specific player match
    if params[:player_match_id].present?
      @player_match = PlayerMatch.joins(:player)
                                .where(id: params[:player_match_id], match_id: @match.id)
                                .where(players: { team_id: current_user.team_id })
                                .first
    else
      render json: { error: 'Player match ID required' }, status: :bad_request
      return
    end

    unless @player_match
      render json: { error: 'Player match not found' }, status: :not_found
      return
    end

    @player = @player_match.player

    # Calculate all the same data as in the show method
    calculate_best_worst_metrics(@player_match, @match, @player.team_id)

    # Radar chart data
    @radar_player_data = {
      attack: @player_match.attack_rating || 0,
      defense: @player_match.defense_rating || 0,
      discipline: @player_match.discipline_rating || 0,
      work_rate: @player_match.work_rate_rating || 0,
      skills: @player_match.skills_rating || 0,
      consistency: @player_match.consistency_rating || 0
    }

    # Team averages for radar chart
    team_players = PlayerMatch.joins(:player)
                             .where(match_id: @match.id)
                             .where(players: { team_id: @player.team_id })
                             .where("time_played > 0")

    @radar_team_data = {
      attack: team_players.where.not(attack_rating: nil).average(:attack_rating)&.round(1) || 0,
      defense: team_players.where.not(defense_rating: nil).average(:defense_rating)&.round(1) || 0,
      discipline: team_players.where.not(discipline_rating: nil).average(:discipline_rating)&.round(1) || 0,
      work_rate: team_players.where.not(work_rate_rating: nil).average(:work_rate_rating)&.round(1) || 0,
      skills: team_players.where.not(skills_rating: nil).average(:skills_rating)&.round(1) || 0,
      consistency: team_players.where.not(consistency_rating: nil).average(:consistency_rating)&.round(1) || 0
    }

    respond_to do |format|
      format.json {
        render json: {
          player_name: @player.name,
          radar_player_data: @radar_player_data,
          radar_team_data: @radar_team_data,
          best_5_metrics: @best_5_metrics,
          worst_5_metrics: @worst_5_metrics,
          player_match: {
            id: @player_match.id,
            # Add all the stats needed for the detailed tables
            try: @player_match.try || 0,
            try_assist: @player_match.try_assist || 0,
            linebreak: @player_match.linebreak || 0,
            linebreak_assists: @player_match.linebreak_assists || 0,
            positive_carry: @player_match.positive_carry || 0,
            carries: @player_match.carries || 0,
            conversion: @player_match.conversion || 0,
            missed_conversion: @player_match.missed_conversion || 0,
            penalty_kick_goal: @player_match.penalty_kick_goal || 0,
            missed_penalty_kick_goals: @player_match.missed_penalty_kick_goals || 0,
            drop_goal: @player_match.drop_goal || 0,
            missed_drop_goals: @player_match.missed_drop_goals || 0,
            mod_game_plus: @player_match.mod_game_plus || 0,
            positive_tackle: @player_match.positive_tackle || 0,
            neutral_tackle: @player_match.neutral_tackle || 0,
            negative_tackle: @player_match.negative_tackle || 0,
            assist_tackle: @player_match.assist_tackle || 0,
            missed_tackle: @player_match.missed_tackle || 0,
            turnover: @player_match.turnover || 0,
            lineout_turnover: @player_match.lineout_turnover || 0,
            aerial_duel_won: @player_match.aerial_duel_won || 0,
            aerial_duel_lost: @player_match.aerial_duel_lost || 0,
            positive_offload: @player_match.positive_offload || 0,
            negative_offload: @player_match.negative_offload || 0,
            lineout_won_jump: @player_match.lineout_won_jump || 0,
            lineout_won_no_jump: @player_match.lineout_won_no_jump || 0,
            introduction_won: @player_match.introduction_won || 0,
            introduction_lost: @player_match.introduction_lost || 0,
            scrum_dominant: @player_match.scrum_dominant || 0,
            penalties_conceded: @player_match.penalties_conceded || 0,
            pen_offside: @player_match.pen_offside || 0,
            pen_breakdown: @player_match.pen_breakdown || 0,
            pen_scrum: @player_match.pen_scrum || 0,
            pen_others: @player_match.pen_others || 0,
            yellow: @player_match.yellow || 0,
            red: @player_match.red || 0,
            knock_on: @player_match.knock_on || 0,
            other_mistakes: @player_match.other_mistakes || 0,
            mod_game_minus: @player_match.mod_game_minus || 0,
            time_played: @player_match.time_played || 0
          }
        }
      }
    end
  end

  private

  def calculate_team_average_ratings(match, team_id)
    # Get all player matches for this team in this match with ratings
    team_player_matches = match.player_matches.joins(:player).where(players: { team_id: team_id })
                               .where.not(
                                 attack_rating: nil,
                                 defense_rating: nil,
                                 consistency_rating: nil,
                                 discipline_rating: nil,
                                 skills_rating: nil,
                                 work_rate_rating: nil
                               )

    if team_player_matches.empty?
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

    # Calculate team averages for this match
    {
      "Attack" => team_player_matches.average(:attack_rating)&.round(1) || 5.0,
      "Defense" => team_player_matches.average(:defense_rating)&.round(1) || 5.0,
      "Work Rate" => team_player_matches.average(:work_rate_rating)&.round(1) || 5.0,
      "Discipline" => team_player_matches.average(:discipline_rating)&.round(1) || 5.0,
      "Skills" => team_player_matches.average(:skills_rating)&.round(1) || 5.0,
      "Consistency" => team_player_matches.average(:consistency_rating)&.round(1) || 5.0
    }
  end

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
      :coach_notes,
      player_matches_attributes: [:id, :player_id, :position, :_destroy, :coach_notes, :player_notes]
    )
  end

  def require_admin_or_coach
    unless current_user.role == 'admin' || current_user.role == 'coach'
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
    Rails.logger.info "process_match_csv called with #{csv_data.count} rows"
    return if csv_data.empty?

    # Ensure database connection is healthy
    ActiveRecord::Base.connection.verify!
    Rails.logger.info "Database connection verified"

    ActiveRecord::Base.transaction do
      Rails.logger.info "Starting CSV processing transaction"
      # Get match data from first row (excluding totals)
      first_row = csv_data.first

      # Extract match information from the row - using correct column names from your CSV
      date_str = first_row.to_h['DATA']&.strip
      home_team_name = first_row.to_h['EQUIPA CASA']&.strip
      away_team_name = first_row.to_h['EQUIPA FORA']&.strip
      home_points = first_row.to_h['PONTOS CASA']&.strip
      away_points = first_row.to_h['PONTOS FORA']&.strip
      result = "#{home_points} - #{away_points}" if home_points.present? && away_points.present?
      competition = first_row.to_h['COMPETIÇÃO']&.strip
      season = Date.current.year.to_s # Default to current year since not in CSV

      # Debug logging
      Rails.logger.info "Extracted match data:"
      Rails.logger.info "Date: '#{date_str}'"
      Rails.logger.info "Home team: '#{home_team_name}'"
      Rails.logger.info "Away team: '#{away_team_name}'"
      Rails.logger.info "Competition: '#{competition}'"

      # Parse date
      Rails.logger.info "Parsing date from: '#{date_str}'"
      begin
        # Handle the format "27-Sep" by adding current year
        if date_str&.match?(/\d{1,2}-\w{3}/)
          date = Date.parse("#{date_str}-#{Date.current.year}")
        else
          date = Date.parse(date_str) if date_str
        end
      rescue Date::Error => e
        Rails.logger.error "Failed to parse date '#{date_str}': #{e.message}"
        date = Date.current # Default to today
      end

      # Validate team names before proceeding
      if home_team_name.blank? || away_team_name.blank?
        raise "Invalid team names: Home team: '#{home_team_name}', Away team: '#{away_team_name}'"
      end

      # Find or create teams with error handling
      begin
        home_team = Team.find_or_create_by!(name: home_team_name) do |team|
          team.level = 'Senior'
          team.classification = 5
          team.main_color = '#000000'
          team.secondary_color = '#000000'
          Rails.logger.info "Created home team: #{team.name}"
        end
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error "Failed to create home team '#{home_team_name}': #{e.message}"
        raise "Failed to create home team '#{home_team_name}': #{e.message}"
      end

      begin
        away_team = Team.find_or_create_by!(name: away_team_name) do |team|
          team.level = 'Senior'
          team.classification = 5
          team.main_color = '#000000'
          team.secondary_color = '#000000'
          Rails.logger.info "Created away team: #{team.name}"
        end
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error "Failed to create away team '#{away_team_name}': #{e.message}"
        raise "Failed to create away team '#{away_team_name}': #{e.message}"
      end

      # Debug: Verify teams were created/found successfully
      Rails.logger.info "Home team: #{home_team.inspect}"
      Rails.logger.info "Away team: #{away_team.inspect}"
      Rails.logger.info "Home team valid?: #{home_team.valid?}"
      Rails.logger.info "Away team valid?: #{away_team.valid?}"

      if home_team.nil? || away_team.nil?
        raise "Failed to create/find teams: Home team: #{home_team.inspect}, Away team: #{away_team.inspect}"
      end

      if !home_team.valid?
        Rails.logger.error "Home team validation errors: #{home_team.errors.full_messages}"
        raise "Home team validation failed: #{home_team.errors.full_messages.join(', ')}"
      end

      if !away_team.valid?
        Rails.logger.error "Away team validation errors: #{away_team.errors.full_messages}"
        raise "Away team validation failed: #{away_team.errors.full_messages.join(', ')}"
      end

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

      # Create match with detailed error handling
      Rails.logger.info "Creating match with:"
      Rails.logger.info "Season: '#{season}'"
      Rails.logger.info "Competition: '#{competition}'"
      Rails.logger.info "Date: #{date}"
      Rails.logger.info "Home team: #{home_team.inspect}"
      Rails.logger.info "Away team: #{away_team.inspect}"
      Rails.logger.info "Result: '#{result}'"

      begin
        match = Match.create!(
          season: season,
          competition: competition,
          date: date,
          home_team_id: home_team.id,
          away_team_id: away_team.id,
          result: result
        )
        Rails.logger.info "Match created successfully: #{match.inspect}"
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error "Match creation failed: #{e.message}"
        Rails.logger.error "Match errors: #{e.record.errors.full_messages}"
        Rails.logger.error "Match attributes being saved:"
        Rails.logger.error "  season: #{season}"
        Rails.logger.error "  competition: #{competition}"
        Rails.logger.error "  date: #{date}"
        Rails.logger.error "  home_team_id: #{home_team.id}"
        Rails.logger.error "  away_team_id: #{away_team.id}"
        Rails.logger.error "  result: #{result}"
        raise e
      end

      # Process each player row (excluding totals row)
      team_stats_data = nil
      players_processed = 0

      # Debug: Print CSV headers
      Rails.logger.info "CSV Headers: #{csv_data.headers}"
      Rails.logger.info "Total CSV rows to process: #{csv_data.count}"

      csv_data.each_with_index do |row, index|
        player_name = row[0]&.strip  # Use index instead of column name

        # Skip totals row, empty names, or invalid names, but capture team stats from first row
        if player_name.blank? ||
           player_name.length < 2 ||
           player_name.upcase.include?('TOTAL') ||
           player_name.include?('vs') ||
           player_name.match?(/^\s*;/) # Skip rows that start with semicolon (like ";TOTAL")
          Rails.logger.info "Skipping invalid player name: '#{player_name}'"
          next
        end

        # Capture team-level stats from the first player row (they're the same for all rows)
        if team_stats_data.nil?
          # Helper method to safely convert to integer
          safe_to_i = ->(value) { value.to_s.strip.to_i }

          # Debug: Print the raw values
          Rails.logger.info "Raw CSV values for team stats:"
          Rails.logger.info "ALINHAMENTO GANHOS SPORT: '#{row.to_h['ALINHAMENTO GANHOS SPORT']}'"
          Rails.logger.info "ALINHAMENTO TOTAIS SPORT: '#{row.to_h['ALINHAMENTO TOTAIS SPORT']}'"
          Rails.logger.info "ALINHAMENTO GANHOS ADVERSARIO: '#{row.to_h['ALINHAMENTO GANHOS ADVERSARIO']}'"
          Rails.logger.info "ALINHAMENTO TOTAIS ADVERSARIO: '#{row.to_h['ALINHAMENTO TOTAIS ADVERSARIO']}'"
          Rails.logger.info "FO GANHAS SPORT: '#{row.to_h['FO GANHAS SPORT ']}'"
          Rails.logger.info "FO TOTAIS SPORT: '#{row.to_h['FO TOTAIS SPORT ']}'"
          Rails.logger.info "FO GANHAS ADVERSARIO: '#{row.to_h['FO GANHAS ADVERSARIO']}'"
          Rails.logger.info "FO TOTAIS ADVERSARIO: '#{row.to_h['FO TOTAIS ADVERSARIO']}'"

          lineouts_ganhos_sport = safe_to_i.call(row.to_h['ALINHAMENTO GANHOS SPORT'])
          lineouts_totais_sport = safe_to_i.call(row.to_h['ALINHAMENTO TOTAIS SPORT'])
          lineouts_ganhos_adversario = safe_to_i.call(row.to_h['ALINHAMENTO GANHOS ADVERSARIO'])
          lineouts_totais_adversario = safe_to_i.call(row.to_h['ALINHAMENTO TOTAIS ADVERSARIO'])
          scrums_ganhos_sport = safe_to_i.call(row.to_h['FO GANHAS SPORT '])
          scrums_totais_sport = safe_to_i.call(row.to_h['FO TOTAIS SPORT '])
          scrums_ganhos_adversario = safe_to_i.call(row.to_h['FO GANHAS ADVERSARIO'])
          scrums_totais_adversario = safe_to_i.call(row.to_h['FO TOTAIS ADVERSARIO'])

          team_stats_data = {
            lineouts_won: lineouts_ganhos_sport,
            lineouts_lost: [lineouts_totais_sport - lineouts_ganhos_sport, 0].max,
            lineouts_stolen: lineouts_ganhos_adversario,
            lineouts_not_stolen: [lineouts_totais_adversario - lineouts_ganhos_adversario, 0].max,
            scrums_won: scrums_ganhos_sport,
            scrums_lost: [scrums_totais_sport - scrums_ganhos_sport, 0].max,
            scrums_stolen: scrums_ganhos_adversario,
            scrums_not_stolen: [scrums_totais_adversario - scrums_ganhos_adversario, 0].max
          }

          Rails.logger.info "Extracted team stats: #{team_stats_data}"
        end

        # Find player by name
        player = Player.find_by(name: player_name)

        if player.nil?
          Rails.logger.warn "Player '#{player_name}' not found, skipping..."
          Rails.logger.info "Available players with similar names:"
          similar_players = Player.where("name ILIKE ?", "%#{player_name.split.first}%").limit(5)
          similar_players.each { |p| Rails.logger.info "  - #{p.name}" }
          next
        end

        # Create player match with error handling
        begin
          players_processed += 1
          Rails.logger.info "Processing player #{players_processed}: #{player_name}"
          player_match = match.player_matches.create!(
            player: player,
            position: index + 1  # Set position based on CSV row index (1-based)
          )
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.error "Failed to create player_match for '#{player_name}': #{e.message}"
          next
        end

        # Create actions based on stats with error handling
        begin
          create_actions_from_stats(player_match, row, csv_data.headers, index)
          Rails.logger.info "Created stats for player '#{player_name}'"
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.error "Failed to create stats for player '#{player_name}': #{e.message}"
          # Continue processing other players even if one fails
        rescue => e
          Rails.logger.error "Failed to create stats for player '#{player_name}': #{e.message}"
          # Continue processing other players even if stats creation fails
        end
      end

      # Create team stats after processing all players
      Rails.logger.info "Players processed: #{players_processed}"
      Rails.logger.info "Team stats data: #{team_stats_data.inspect}"
      if team_stats_data
        Rails.logger.info "Creating team stats for match #{match.id}"
        teamstat = create_team_stats(match, team_stats_data)
        # Calculate team ratings after team stats are saved
        begin
          teamstat.calculate_ratings!
          Rails.logger.info "Calculated team ratings for match #{match.id}"
        rescue => e
          Rails.logger.error "Failed to calculate team ratings for match #{match.id}: #{e.message}"
        end
      else
        Rails.logger.warn "No team stats data found, skipping teamstat creation"
      end

      Rails.logger.info "Calculating team averages for match #{match.id}"
      calculate_team_average(match)

      # Calculate Python-based ratings for all players
      Rails.logger.info "Calculating Python-based ratings for match #{match.id}"
      begin
        PythonRatingService.new(match).calculate_all_ratings!
        Rails.logger.info "Successfully calculated Python ratings for match #{match.id}"
      rescue => e
        Rails.logger.error "Failed to calculate Python ratings for match #{match.id}: #{e.message}"
        # Continue without failing the entire process
      end

      Rails.logger.info "CSV processing transaction completed successfully"
    end # End transaction
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Database validation error during CSV processing: #{e.message}"
    Rails.logger.error "Record errors: #{e.record.errors.full_messages}" if e.record
    raise "Database validation failed: #{e.message}"
  rescue ActiveRecord::StatementInvalid => e
    Rails.logger.error "Database statement error during CSV processing: #{e.message}"
    raise "Database error: #{e.message}"
  rescue StandardError => e
    Rails.logger.error "Unexpected error during CSV processing: #{e.class}: #{e.message}"
    Rails.logger.error "Backtrace: #{e.backtrace.first(5).join("\n")}"
    raise e
  end

  def create_actions_from_stats(player_match, row, headers, index)
    # Map CSV columns to PlayerMatch field names based on your actual CSV format
    field_mapping = {
      'MIN' => 'time_played',
      'ENSAIOS' => 'try',
      'CONVERSÕES FEITAS' => 'conversion',
      'CONVERSÕES TOTAL' => nil, # We only track made conversions
      'PEN POSTES CONVERTIDAS' => 'penalty_kick_goal',
      'PEN POSTES TOTAL' => nil, # We only track made penalty kicks
      'DROPS CONVERTIDOS' => 'drop_goal',
      'DROPS TOTAL' => nil, # We only track made drops
      'ASSISTÊNCIA' => 'try_assist',
      'PL. OFENSIVA' => 'positive_tackle',
      'PL. NEUTRA' => 'neutral_tackle',
      'PL. DEFENSIVA' => 'negative_tackle',
      'PLAC. ASSISTENTE' => 'assist_tackle',
      'PL. FALHADA' => 'missed_tackle',
      'FO DOMINANTE' => 'scrum_dominant',
      'RECUPERAÇÃO AL.' => 'lineout_turnover',
      'AL. SPORT COM SALTO' => 'lineout_won_jump',
      'AL. SPORT SEM SALTO' => 'lineout_won_no_jump',
      'INTRODUÇÕES GANHAS' => 'introduction_won',
      'TURNOVERS' => 'turnover',
      'MOD. JOGO +' => 'mod_game_plus',
      'MOD. JOGO -' => 'mod_game_minus',
      'PEN - Fora de Jogo' => 'pen_offside',
      'PEN - Jogo no Chão' => 'pen_breakdown',
      'PEN - F.O.' => 'pen_scrum',
      'PEN - Outros' => 'pen_others',
      'OUTROS ERROS' => 'other_mistakes',
      'DUELOS AEREOS (+)' => 'aerial_duel_won',
      'DUELOS AEREOS (–)' => 'aerial_duel_lost',
      'OFFLOADS (+)' => 'positive_offload',
      'OFFLOADS (–)' => 'negative_offload',
      'PASSE QL' => 'linebreak_assists', # No direct mapping - could be added as new field if needed
      'QUEBRAS DE LINHA' => 'linebreak',
      'AVANTS' => 'knock_on',
      'CARRIES (+)' => 'positive_carry',
      'CARRIES' => 'carries'
    }

    # Update player_match with stats from CSV
    update_attributes = {}

    if index < 15
      update_attributes['started'] = true
    end

    field_mapping.each do |csv_column, field_name|
      next if field_name.nil?

      value = row[csv_column]
      next if value.blank?

      # Convert to integer, default to 0 if conversion fails
      numeric_value = value.to_s.strip.to_i
      update_attributes[field_name] = numeric_value
    end

    # Handle calculated fields
    introduções_totais = row.to_h['INTRODUÇÕES TOTAIS'].to_s.strip.to_i
    introduções_ganhas = row.to_h['INTRODUÇÕES GANHAS'].to_s.strip.to_i
    if introduções_totais > 0 && introduções_ganhas >= 0
      update_attributes['introduction_lost'] = introduções_totais - introduções_ganhas
    end

    # Handle missed conversions if we have totals
    conversões_totais = row.to_h['CONVERSÕES TOTAL'].to_s.strip.to_i
    conversões_feitas = row.to_h['CONVERSÕES FEITAS'].to_s.strip.to_i
    if conversões_totais > 0 && conversões_feitas >= 0
      update_attributes['missed_conversion'] = conversões_totais - conversões_feitas
    end

    # Handle missed penalty kicks if we have totals
    pen_totais = row.to_h['PEN POSTES TOTAL'].to_s.strip.to_i
    pen_convertidas = row.to_h['PEN POSTES CONVERTIDAS'].to_s.strip.to_i
    if pen_totais > 0 && pen_convertidas >= 0
      update_attributes['missed_penalty_kick_goals'] = pen_totais - pen_convertidas
    end

    # Handle missed drops if we have totals
    drops_totais = row.to_h['DROPS TOTAL'].to_s.strip.to_i
    drops_convertidos = row.to_h['DROPS CONVERTIDOS'].to_s.strip.to_i
    if drops_totais > 0 && drops_convertidos >= 0
      update_attributes['missed_drop_goals'] = drops_totais - drops_convertidos
    end

    # Update the player_match with all the stats
    player_match.update!(update_attributes) if update_attributes.any?
  end

  def create_team_stats(match, team_stats_data)
    # Create home team stats (the stats appear to be for the home team based on CSV structure)
    teamstat = match.teamstat.create!(
      team_id: current_user.team_id,
      lineouts_won: team_stats_data[:lineouts_won],
      lineouts_lost: team_stats_data[:lineouts_lost],
      lineouts_stolen: team_stats_data[:lineouts_stolen],
      lineouts_not_stolen: team_stats_data[:lineouts_not_stolen],
      scrums_won: team_stats_data[:scrums_won],
      scrums_lost: team_stats_data[:scrums_lost],
      scrums_stolen: team_stats_data[:scrums_stolen],
      scrums_not_stolen: team_stats_data[:scrums_not_stolen]
    )

    Rails.logger.info "Created home team stats: #{teamstat.inspect}"
    teamstat
  end

  def calculate_team_average(match)
    # Only count players who have played one or more minutes
    played_players = match.player_matches.where("CAST(time_played AS INTEGER) > 0")
    players_count = played_players.count

    return if players_count == 0 # Avoid division by zero

    match.avg_time_played = played_players.sum("CAST(time_played AS INTEGER)").to_f / players_count
    match.avg_positive_tackle = played_players.sum(:positive_tackle).to_f / players_count
    match.avg_neutral_tackle = played_players.sum(:neutral_tackle).to_f / players_count
    match.avg_negative_tackle = played_players.sum(:negative_tackle).to_f / players_count
    match.avg_assist_tackle = played_players.sum(:assist_tackle).to_f / players_count
    match.avg_missed_tackle = played_players.sum(:missed_tackle).to_f / players_count
    match.avg_turnover = played_players.sum(:turnover).to_f / players_count
    match.avg_pen_offside = played_players.sum(:pen_offside).to_f / players_count
    match.avg_pen_breakdown = played_players.sum(:pen_breakdown).to_f / players_count
    match.avg_pen_scrum = played_players.sum(:pen_scrum).to_f / players_count
    match.avg_pen_others = played_players.sum(:pen_others).to_f / players_count
    match.avg_aerial_duel_won = played_players.sum(:aerial_duel_won).to_f / players_count
    match.avg_aerial_duel_lost = played_players.sum(:aerial_duel_lost).to_f / players_count
    match.avg_positive_offload = played_players.sum(:positive_offload).to_f / players_count
    match.avg_negative_offload = played_players.sum(:negative_offload).to_f / players_count
    match.avg_linebreak = played_players.sum(:linebreak).to_f / players_count
    match.avg_knock_on = played_players.sum(:knock_on).to_f / players_count
    match.avg_positive_carry = played_players.sum(:positive_carry).to_f / players_count
    match.avg_carries = played_players.sum(:carries).to_f / players_count
    match.save
  end

  def calculate_top_players(match)
    @positive_tackles_top_players = match.player_matches.order(Arel.sql("COALESCE(positive_tackle, 0) DESC")).limit(5)
    @turnovers_top_players = match.player_matches.order(Arel.sql("COALESCE(turnover, 0) DESC")).limit(5)
    @penalties_top_players = match.player_matches
      .select(Arel.sql("*, (COALESCE(pen_offside, 0) + COALESCE(pen_breakdown, 0) + COALESCE(pen_scrum, 0) + COALESCE(pen_others, 0)) as total_penalties"))
      .order(Arel.sql("total_penalties DESC"))
      .limit(5)
    @carries_top_players = match.player_matches.order(Arel.sql("COALESCE(carries, 0) DESC")).limit(5)
    @positive_carries_top_players = match.player_matches.order(Arel.sql("COALESCE(positive_carry, 0) DESC")).limit(5)
    @positive_offloads_top_players = match.player_matches.order(Arel.sql("COALESCE(positive_offload, 0) DESC")).limit(5)
    @linebreaks_top_players = match.player_matches.order(Arel.sql("COALESCE(linebreak, 0) DESC")).limit(5)
  end

  def calculate_best_worst_metrics(player_match, match, team_id)
    # Get all player matches for this match from the same team
    team_player_matches = PlayerMatch.joins(:player)
                                    .where(match_id: match.id)
                                    .where(players: { team_id: team_id })
                                    .where("time_played > 0")

    return if team_player_matches.empty?

    # Define all metrics to compare
    metrics = [
      {
        name: "% Tackles Made",
        player_value: calculate_tackle_success_rate(player_match),
        team_avg: calculate_team_avg_tackle_success_rate(team_player_matches),
        format: :percentage
      },
      {
        name: "Tackle Impact",
        player_value: calculate_tackle_impact(player_match),
        team_avg: calculate_team_avg_tackle_impact(team_player_matches),
        format: :decimal
      },
      {
        name: "% Carries with Gain",
        player_value: calculate_carry_success_rate(player_match),
        team_avg: calculate_team_avg_carry_success_rate(team_player_matches),
        format: :percentage
      },
      {
        name: "% Mod Game",
        player_value: calculate_mod_game_success_rate(player_match),
        team_avg: calculate_team_avg_mod_game_success_rate(team_player_matches),
        format: :percentage
      },
      {
        name: "Total Actions",
        player_value: calculate_total_actions(player_match),
        team_avg: calculate_team_avg_total_actions(team_player_matches),
        format: :integer
      },
      {
        name: "Linebreaks",
        player_value: player_match.linebreak || 0,
        team_avg: team_player_matches.sum("COALESCE(linebreak, 0)").to_f / team_player_matches.count,
        format: :integer
      },
      {
        name: "Turnovers Won",
        player_value: player_match.turnover || 0,
        team_avg: team_player_matches.sum("COALESCE(turnover, 0)").to_f / team_player_matches.count,
        format: :integer
      },
      {
        name: "Penalties Conceded",
        player_value: player_match.penalties_conceded || 0,
        team_avg: calculate_team_avg_penalties(team_player_matches),
        format: :integer,
        inverse: true
      },
      {
        name: "Knock Ons",
        player_value: player_match.knock_on || 0,
        team_avg: team_player_matches.sum("COALESCE(knock_on, 0)").to_f / team_player_matches.count,
        format: :integer,
        inverse: true
      },
      {
        name: "Missed Tackles",
        player_value: player_match.missed_tackle || 0,
        team_avg: team_player_matches.sum("COALESCE(missed_tackle, 0)").to_f / team_player_matches.count,
        format: :integer,
        inverse: true
      }
    ]

    # Calculate differences and sort
    metrics_with_diff = metrics.map do |metric|
      difference = metric[:player_value] - metric[:team_avg]
      difference = -difference if metric[:inverse]
      metric.merge(difference: difference)
    end

    # Sort by difference (best first)
    sorted_metrics = metrics_with_diff.sort_by { |m| -m[:difference] }

    # Get best 5 and worst 5
    @best_5_metrics = sorted_metrics.first(5)
    @worst_5_metrics = sorted_metrics.last(5).reverse
  end

  def calculate_tackle_success_rate(player_match)
    total_tackles = (player_match.positive_tackle || 0) + (player_match.neutral_tackle || 0) +
                   (player_match.negative_tackle || 0) + (player_match.assist_tackle || 0)
    missed_tackles = player_match.missed_tackle || 0
    return 0 if (total_tackles + missed_tackles) == 0
    (total_tackles.to_f / (total_tackles + missed_tackles) * 100).round(1)
  end

  def calculate_team_avg_tackle_success_rate(team_player_matches)
    rates = team_player_matches.map { |pm| calculate_tackle_success_rate(pm) }.reject(&:zero?)
    rates.empty? ? 0 : (rates.sum / rates.count.to_f).round(1)
  end

  def calculate_tackle_impact(player_match)
    ((player_match.positive_tackle || 0) * 1.5 +
     (player_match.neutral_tackle || 0) * 1.0 +
     (player_match.negative_tackle || 0) * 0.3 +
     (player_match.assist_tackle || 0) * 0.8).round(1)
  end

  def calculate_team_avg_tackle_impact(team_player_matches)
    impacts = team_player_matches.map { |pm| calculate_tackle_impact(pm) }
    (impacts.sum / impacts.count.to_f).round(1)
  end

  def calculate_carry_success_rate(player_match)
    total_carries = (player_match.positive_carry || 0) + (player_match.carries || 0)
    return 0 if total_carries == 0
    ((player_match.positive_carry || 0).to_f / total_carries * 100).round(1)
  end

  def calculate_team_avg_carry_success_rate(team_player_matches)
    rates = team_player_matches.map { |pm| calculate_carry_success_rate(pm) }.reject(&:zero?)
    rates.empty? ? 0 : (rates.sum / rates.count.to_f).round(1)
  end

  def calculate_mod_game_success_rate(player_match)
    mod_plus = player_match.mod_game_plus || 0
    mod_minus = player_match.mod_game_minus || 0
    mod_total = mod_plus + mod_minus
    return 0 if mod_total == 0
    (mod_plus.to_f / mod_total * 100).round(1)
  end

  def calculate_team_avg_mod_game_success_rate(team_player_matches)
    rates = team_player_matches.map { |pm| calculate_mod_game_success_rate(pm) }.reject(&:zero?)
    rates.empty? ? 0 : (rates.sum / rates.count.to_f).round(1)
  end

  def calculate_total_actions(player_match)
    total_carries = (player_match.positive_carry || 0) + (player_match.carries || 0)
    total_tackles = (player_match.positive_tackle || 0) + (player_match.neutral_tackle || 0) +
                   (player_match.negative_tackle || 0) + (player_match.assist_tackle || 0)
    total_carries + total_tackles + (player_match.turnover || 0) + (player_match.mod_game_plus || 0)
  end

  def calculate_team_avg_total_actions(team_player_matches)
    actions = team_player_matches.map { |pm| calculate_total_actions(pm) }
    (actions.sum / actions.count.to_f).round(1)
  end

  def calculate_team_avg_penalties(team_player_matches)
    penalties = team_player_matches.map do |pm|
      (pm.pen_offside || 0) + (pm.pen_breakdown || 0) + (pm.pen_scrum || 0) + (pm.pen_others || 0)
    end
    (penalties.sum / penalties.count.to_f).round(1)
  end

end
