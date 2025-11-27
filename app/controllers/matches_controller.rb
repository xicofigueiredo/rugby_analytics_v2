require 'csv'
include SportHelper
include RcmHelper

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
    @mvp_player = @players.where(overall_rating: @players.maximum(:overall_rating)).first
    @starting_players = @players.where(started: true)
    @bench_players = @players.where(started: false)
    @scorer_players = @players.where("try > 0 OR conversion > 0 OR penalty_kick_goal > 0 OR drop_goal > 0")

    # Set player match based on user role and context
    Rails.logger.info "Current user role: #{current_user.role}, player_id: #{current_user.player_id}, team_id: #{current_user.team_id}"

    if current_user.role == "player" && current_user.player_id.present?
      # For players, show all players from their team in the dropdown but default to themselves
      @players = @players.joins(:player).where(players: { team_id: current_user.team_id })

      # Allow players to view specific player via player_match_id parameter (but only from their team)
      if params[:player_match_id].present?
        @player_match = PlayerMatch.joins(:player)
                                  .where(id: params[:player_match_id], match_id: @match.id)
                                  .where(players: { team_id: current_user.team_id })
                                  .first
      else
        # Set their own player_match as default
        @player_match = PlayerMatch.where(match_id: @match.id, player_id: current_user.player_id).first

        # If player didn't play in this match (no stats/time_played = 0), set to nil to show placeholder
        if @player_match && (@player_match.time_played.nil? || @player_match.time_played == 0)
          @player_match = nil
        end
      end
      @player = @player_match&.player
      Rails.logger.info "Player mode: Found player_match for player_id #{current_user.player_id}: #{@player_match&.id}"
    elsif current_user.role == "coach" || current_user.role == "admin"
      # Filter players to only show coach's team in the dropdown
      @players = @players.joins(:player).where(players: { team_id: current_user.team_id })

      # For coaches/admins, allow viewing specific player via player_match_id parameter
      if params[:player_match_id].present?
        @player_match = PlayerMatch.joins(:player)
                                  .where(id: params[:player_match_id], match_id: @match.id)
                                  .first
      elsif params[:player_id].present?
        @player_match = PlayerMatch.joins(:player)
                                  .where(match_id: @match.id, player_id: params[:player_id])
                                  .first
      else
        # Default to first player from the coach's team
        @player_match = PlayerMatch.joins(:player)
                                  .where(match_id: @match.id)
                                  .where(players: { team_id: current_user.team_id })
                                  .where("time_played > 0")
                                  .order(:position)
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

    # Create stats data for JavaScript (after calculate_top_players)
    @stats_data = {
      "positive_tackles" => (@positive_tackles_top_players || []).map { |pm| { name: pm.player.name, value: pm.positive_tackle || 0, minutes_played: pm.time_played || 0 } },
      "total_tackles" => (@total_tackles_top_players || []).map { |pm| { name: pm.player.name, value: pm.total_tackles || 0, minutes_played: pm.player_match.time_played || 0 } },
      "turnovers" => (@turnovers_top_players || []).map { |pm| { name: pm.player.name, value: pm.turnover || 0, minutes_played: pm.time_played || 0 } },
      "penalties" => (@penalties_top_players || []).map { |pm| { name: pm.player.name, value: pm.total_penalties || 0, minutes_played: pm.player_match.time_played || 0 } },
      "carries" => (@carries_top_players || []).map { |pm| { name: pm.player.name, value: (pm.carries || 0) + (pm.positive_carry || 0), minutes_played: pm.time_played || 0 } },
      "positive_carries" => (@positive_carries_top_players || []).map { |pm| { name: pm.player.name, value: pm.positive_carry || 0, minutes_played: pm.time_played || 0 } },
      "offloads_good" => (@offloads_good_top_players || []).map { |pm| { name: pm.player.name, value: pm.offloads_good || 0, minutes_played: pm.player_match.time_played || 0 } },
      "offloads_bad" => (@offloads_bad_top_players || []).map { |pm| { name: pm.player.name, value: pm.offloads_bad || 0, minutes_played: pm.player_match.time_played || 0 } },
      "linebreaks" => (@linebreaks_top_players || []).map { |pm| { name: pm.player.name, value: pm.linebreak || 0, minutes_played: pm.time_played || 0 } },
      "knock_ons" => (@knock_ons_top_players || []).map { |pm| { name: pm.player.name, value: pm.knock_on || 0, minutes_played: pm.time_played || 0 } },
      "missed_tackles" => (@missed_tackles_top_players || []).map { |pm| { name: pm.player.name, value: pm.missed_tackle || 0, minutes_played: pm.time_played || 0 } }
    }

    # Rails.logger.info "Stats data created: #{@stats_data.inspect}"

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
          "Attack" => 0,
          "Defense" => 0,
          "Work Rate" => 0,
          "Discipline" => 0,
          "Skills" => 0,
          "Consistency" => 0
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
          "Attack" => 0,
          "Defense" => 0,
          "Work Rate" => 0,
          "Discipline" => 0,
          "Skills" => 0,
          "Consistency" => 0
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
            "Attack" => @player_match.attack_rating || 0.0,
            "Defense" => @player_match.defense_rating || 0.0,
            "Work Rate" => @player_match.work_rate_rating || 0.0,
            "Discipline" => @player_match.discipline_rating || 0.0,
            "Skills" => @player_match.skills_rating || 0.0,
            "Consistency" => @player_match.consistency_rating || 0.0
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
        @player_season_average_performance_data = calculate_team_average_ratings(@match)

      end

    # Set up player match performance data for all teams
    if @player_match
      @player_match_performance_data = {
        "Attack" => @player_match.attack_rating || 0.0,
        "Defense" => @player_match.defense_rating || 0.0,
        "Work Rate" => @player_match.work_rate_rating || 0.0,
        "Discipline" => @player_match.discipline_rating || 0.0,
        "Skills" => @player_match.skills_rating || 0.0,
        "Consistency" => @player_match.consistency_rating || 0.0
      }
    else
      @player_match_performance_data = {
        "Attack" => 0,
        "Defense" => 0,
        "Work Rate" => 0,
        "Discipline" => 0,
        "Skills" => 0,
        "Consistency" => 0
      }
    end

    # Calculate team average ratings for this match
    @player_season_average_performance_data = calculate_team_average_ratings(@match)

    # Calculate best and worst performance metrics
    if @player_match
      # Reload to ensure fresh data
      @player_match.reload
      calculate_best_worst_metrics(@player_match, @match)
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
      ["Total Tackles", "total_tackles"],
      ["Positive Tackles", "positive_tackles"],
      ["Turnovers", "turnovers"],
      ["Penalties", "penalties"],
      ["Total Carries", "carries"],
      ["Positive Carries", "positive_carries"],
      ["Offloads Good", "offloads_good"],
      ["Offloads Bad", "offloads_bad"],
      ["Linebreaks", "linebreaks"],
      ["Knock Ons", "knock_ons"],
      ["Missed Tackles", "missed_tackles"]
    ]

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
        format.json { render json: { status: 'success', message: 'Player data updated successfully.' } }
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
      # Auto-detect delimiter by reading first line
      first_line = File.open(uploaded_file.path, &:readline)
      delimiter = first_line.include?(';') ? ';' : ','
      Rails.logger.info "Detected CSV delimiter: '#{delimiter}'"

      # Read CSV with detected delimiter
      csv_data = CSV.read(uploaded_file.path, headers: true, col_sep: delimiter)
      Rails.logger.info "CSV read successfully, rows: #{csv_data.count}"
      if current_user.team.name == 'SPORT'
        sport_process_match_csv(csv_data)
      elsif current_user.team.name == 'Montemor'
        rcm_process_match_csv(csv_data)
      end
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
    # Find the specific player match - only from the coach's team
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

    # Reload player_match to ensure fresh data
    @player_match.reload

    # Calculate all the same data as in the show method
    calculate_best_worst_metrics(@player_match, @match)

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
            coach_notes: @player_match.coach_notes,
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

  def calculate_team_average_ratings(match)
    # Get all player matches for this team in this match with ratings
    team_player_matches = match.player_matches
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
        "Attack" => 0,
        "Defense" => 0,
        "Work Rate" => 0,
        "Discipline" => 0,
        "Skills" => 0,
        "Consistency" => 0
      }
    end

    # Calculate team averages for this match
    {
      "Attack" => team_player_matches.average(:attack_rating)&.round(1) || 0.0,
      "Defense" => team_player_matches.average(:defense_rating)&.round(1) || 0.0,
      "Work Rate" => team_player_matches.average(:work_rate_rating)&.round(1) || 0.0,
      "Discipline" => team_player_matches.average(:discipline_rating)&.round(1) || 0.0,
      "Skills" => team_player_matches.average(:skills_rating)&.round(1) || 0.0,
      "Consistency" => team_player_matches.average(:consistency_rating)&.round(1) || 0.0
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

  def calculate_top_players(match)
    @positive_tackles_top_players = match.player_matches.includes(:player).order(Arel.sql("COALESCE(positive_tackle, 0) DESC")).limit(5)
    @turnovers_top_players = match.player_matches.includes(:player).order(Arel.sql("COALESCE(turnover, 0) DESC")).limit(5)
    @carries_top_players = match.player_matches.includes(:player).order(Arel.sql("COALESCE(carries, 0) + COALESCE(positive_carry, 0) DESC")).limit(5)
    @positive_carries_top_players = match.player_matches.includes(:player).order(Arel.sql("COALESCE(positive_carry, 0) DESC")).limit(5)
    @positive_offloads_top_players = match.player_matches.includes(:player).order(Arel.sql("COALESCE(positive_offload, 0) DESC")).limit(5)
    @linebreaks_top_players = match.player_matches.includes(:player).order(Arel.sql("COALESCE(linebreak, 0) DESC")).limit(5)
    @knock_ons_top_players = match.player_matches.includes(:player).order(Arel.sql("COALESCE(knock_on, 0) DESC")).limit(5)
    @missed_tackles_top_players = match.player_matches.includes(:player).order(Arel.sql("COALESCE(missed_tackle, 0) DESC")).limit(5)

    # Calculate complex stats in Ruby to avoid SQL conflicts
    all_players_with_stats = match.player_matches.includes(:player).map do |pm|
      total_penalties = (pm.pen_offside || 0) + (pm.pen_breakdown || 0) + (pm.pen_scrum || 0) + (pm.pen_others || 0)
      total_tackles = (pm.positive_tackle || 0) + (pm.neutral_tackle || 0) + (pm.negative_tackle || 0) + (pm.assist_tackle || 0)
      offloads_good = pm.positive_offload || 0
      offloads_bad = pm.negative_offload || 0

      OpenStruct.new(
        player: pm.player,
        total_penalties: total_penalties,
        total_tackles: total_tackles,
        offloads_good: offloads_good,
        offloads_bad: offloads_bad,
        player_match: pm
      )
    end

    @penalties_top_players = all_players_with_stats.sort_by(&:total_penalties).reverse.first(5)
    @total_penalties_top_players = all_players_with_stats.sort_by(&:total_penalties).reverse.first(5)
    @total_tackles_top_players = all_players_with_stats.sort_by(&:total_tackles).reverse.first(5)
    @offloads_good_top_players = all_players_with_stats.sort_by(&:offloads_good).reverse.first(5)
    @offloads_bad_top_players = all_players_with_stats.sort_by(&:offloads_bad).reverse.first(5)

    Rails.logger.info "Top players calculated:"
    Rails.logger.info "Positive tackles: #{@positive_tackles_top_players.count} players"
    Rails.logger.info "Total tackles: #{@total_tackles_top_players.count} players"
    Rails.logger.info "Penalties: #{@penalties_top_players.count} players"
  end


  # --- MAIN: build best/worst metrics for a player in a match ---
  def calculate_best_worst_metrics(player_match, match)
    player_match.reload

    team_player_matches = teammates_for_metrics(match, player_match)
    return if team_player_matches.empty?

    metrics = [
      # Percent / composite
      {
        name: "% Tackles Made",
        player_value: calculate_tackle_success_rate(player_match),
        team_avg:     calculate_team_avg_tackle_success_rate(team_player_matches),
        format: :percentage
      },
      {
        name: "Tackle Impact",
        player_value: calculate_tackle_impact(player_match),
        team_avg:     calculate_team_avg_tackle_impact(team_player_matches),
        format: :decimal
      },
      {
        name: "% Positive Tackles",
        player_value: positive_tackle_rate(player_match),
        team_avg:     team_avg_positive_tackle_rate(team_player_matches),
        format: :percentage
      },
      {
        name: "% Carries with Gain",
        player_value: calculate_carry_success_rate(player_match),
        team_avg:     calculate_team_avg_carry_success_rate(team_player_matches),
        format: :percentage
      },
      {
        name: "% Mod Game",
        player_value: calculate_mod_game_success_rate(player_match),
        team_avg:     calculate_team_avg_mod_game_success_rate(team_player_matches),
        format: :percentage
      },

      # Workload / skill counts
      {
        name: "Total Aerial Duels",
        player_value: total_aerial_duels(player_match),
        team_avg:     team_avg_of(team_player_matches) { |pm| total_aerial_duels(pm) },
        format: :integer
      },
      {
        name: "Total Carries",
        player_value: total_carries(player_match),
        team_avg:     team_avg_of(team_player_matches) { |pm| total_carries(pm) },
        format: :integer
      },
      {
        name: "Offloads Good",
        player_value: safe(pm: player_match, attr: :positive_offload),
        team_avg:     team_avg_attr(team_player_matches, :positive_offload),
        format: :integer
      },
      {
        name: "Linebreak Assists",
        player_value: safe(pm: player_match, attr: :linebreak_assists),
        team_avg:     team_avg_attr(team_player_matches, :linebreak_assists),
        format: :integer
      },
      {
        name: "Total Tackles",
        player_value: total_tackles(player_match),
        team_avg:     team_avg_of(team_player_matches) { |pm| total_tackles(pm) },
        format: :integer
      },

      # Harmful (inverse = lower is better)
      {
        name: "Other Mistakes",
        player_value: safe(pm: player_match, attr: :other_mistakes),
        team_avg:     team_avg_attr(team_player_matches, :other_mistakes),
        format: :integer,
        inverse: true
      },
      {
        name: "Knock On",
        player_value: safe(pm: player_match, attr: :knock_on),
        team_avg:     team_avg_attr(team_player_matches, :knock_on),
        format: :integer,
        inverse: true
      },
      {
        name: "Total Penalties",
        player_value: total_penalties(player_match),
        team_avg:     team_avg_penalties(team_player_matches),
        format: :integer,
        inverse: true
      },
      {
        name: "Aerial Duels Won",
        player_value: safe(pm: player_match, attr: :aerial_duel_won),
        team_avg:     team_avg_attr(team_player_matches, :aerial_duel_won),
        format: :integer
      },
      {
        name: "Aerial Duels Lost",
        player_value: safe(pm: player_match, attr: :aerial_duel_lost),
        team_avg:     team_avg_attr(team_player_matches, :aerial_duel_lost),
        format: :integer,
        inverse: true
      },

      # Existing positives
      {
        name: "Positive Carries",
        player_value: safe(pm: player_match, attr: :positive_carry),
        team_avg:     team_avg_attr(team_player_matches, :positive_carry),
        format: :integer
      },
      {
        name: "Linebreaks",
        player_value: safe(pm: player_match, attr: :linebreak),
        team_avg:     team_avg_attr(team_player_matches, :linebreak),
        format: :integer
      },
      {
        name: "Turnovers Won",
        player_value: safe(pm: player_match, attr: :turnover),
        team_avg:     team_avg_attr(team_player_matches, :turnover),
        format: :integer
      },
      {
        name: "Missed Tackles",
        player_value: safe(pm: player_match, attr: :missed_tackle),
        team_avg:     team_avg_attr(team_player_matches, :missed_tackle),
        format: :integer,
        inverse: true
      },
      {
        name: "Offloads Bad",
        player_value: safe(pm: player_match, attr: :negative_offload),
        team_avg:     team_avg_attr(team_player_matches, :negative_offload),
        format: :integer,
        inverse: true
      }
    ]

    # Differences (flip when lower-is-better), ignore equals
    eps = 1e-9
    metrics_with_diff = metrics.map do |metric|
      player_val = (metric[:player_value] || 0).to_f
      team_val   = (metric[:team_avg]     || 0).to_f
      diff = player_val - team_val
      diff = -diff if metric[:inverse]
      diff = 0.0 if diff.abs < eps # squash float noise
      metric.merge(difference: diff)
    end

    positives = metrics_with_diff.select { |m| m[:difference] > 0.0 }
    negatives = metrics_with_diff.select { |m| m[:difference] < 0.0 }

    # Best: largest positive deltas; Worst: most negative deltas
    @best_5_metrics  = positives.sort_by { |m| -m[:difference] }.first(5)
    @worst_5_metrics = negatives.sort_by { |m|  m[:difference] }.first(5)
  end


# --- selection helpers ---

# Returns teammates for this match (same team, time_played > 0),
# excluding the selected player. If that yields none, falls back to include them.
#
# --- metric helpers used by calculate_best_worst_metrics ---

def calculate_tackle_success_rate(pm)
  total = (pm.positive_tackle || 0) +
          (pm.neutral_tackle  || 0) +
          (pm.negative_tackle || 0) +
          (pm.assist_tackle   || 0)
  missed = pm.missed_tackle || 0
  return 0.0 if (total + missed).zero?
  (total.to_f / (total + missed) * 100).round(1)
end

def calculate_team_avg_tackle_success_rate(team_pms)
  rates = team_pms.map { |pm| calculate_tackle_success_rate(pm) }.reject(&:zero?)
  return 0.0 if rates.empty?
  (rates.sum / rates.size).round(1)
end

def calculate_tackle_impact(pm)
  ((pm.positive_tackle || 0) * 1.5 +
   (pm.neutral_tackle  || 0) * 1.0 +
   (pm.negative_tackle || 0) * 0.3 +
   (pm.assist_tackle   || 0) * 0.8).round(1)
end

def calculate_team_avg_tackle_impact(team_pms)
  vals = team_pms.map { |pm| calculate_tackle_impact(pm) }
  return 0.0 if vals.empty?
  (vals.sum / vals.size).round(1)
end

def calculate_carry_success_rate(pm)
  total = (pm.positive_carry || 0) + (pm.carries || 0)
  return 0.0 if total.zero?
  ((pm.positive_carry || 0).to_f / total * 100).round(1)
end

def calculate_team_avg_carry_success_rate(team_pms)
  rates = team_pms.map { |pm| calculate_carry_success_rate(pm) }.reject(&:zero?)
  return 0.0 if rates.empty?
  (rates.sum / rates.size).round(1)
end

def calculate_mod_game_success_rate(pm)
  plus  = pm.mod_game_plus  || 0
  minus = pm.mod_game_minus || 0
  tot = plus + minus
  return 0.0 if tot.zero?
  (plus.to_f / tot * 100).round(1)
end

def calculate_team_avg_mod_game_success_rate(team_pms)
  rates = team_pms.map { |pm| calculate_mod_game_success_rate(pm) }.reject(&:zero?)
  return 0.0 if rates.empty?
  (rates.sum / rates.size).round(1)
end

def calculate_total_actions(pm)
  total_carries(pm) + total_tackles(pm) + (pm.turnover || 0) + (pm.mod_game_plus || 0)
end

def calculate_team_avg_total_actions(team_pms)
  vals = team_pms.map { |pm| calculate_total_actions(pm) }
  return 0.0 if vals.empty?
  (vals.sum / vals.size.to_f).round(1)
end

def calculate_team_avg_penalties(team_pms)
  vals = team_pms.map { |pm| total_penalties(pm) }
  return 0.0 if vals.empty?
  (vals.sum / vals.size.to_f).round(1)
end

def teammates_for_metrics(match, player_match)
  scope = PlayerMatch.joins(:player)
                     .where(match_id: match.id)
                     .where(players: { team_id: player_match.player.team_id })
                     .where("time_played > 0")
                     .includes(:player)
                     .order(:position)

  excluded = scope.where.not(player_id: player_match.player_id)
  list = excluded.any? ? excluded : scope
  # reload to ensure fresh data and return an Array
  list.to_a.each(&:reload)
end

# --- safety helpers ---

def safe(pm:, attr:)
  pm.public_send(attr).to_i
end

def team_avg_of(team_pms)
  vals = team_pms.map { |pm| yield(pm).to_f }
  return 0.0 if vals.empty?
  (vals.sum / vals.size).round(1)
end

def team_avg_attr(team_pms, attr)
  vals = team_pms.map { |pm| safe(pm: pm, attr: attr).to_f }
  return 0.0 if vals.empty?
  (vals.sum / vals.size).round(1)
end

# --- stat aggregations ---

def total_penalties(pm)
  safe(pm: pm, attr: :pen_offside)   +
  safe(pm: pm, attr: :pen_breakdown) +
  safe(pm: pm, attr: :pen_scrum)     +
  safe(pm: pm, attr: :pen_others)
end

def team_avg_penalties(team_pms)
  team_avg_of(team_pms) { |pm| total_penalties(pm) }
end

def total_tackles(pm)
  safe(pm: pm, attr: :positive_tackle) +
  safe(pm: pm, attr: :neutral_tackle)  +
  safe(pm: pm, attr: :negative_tackle) +
  safe(pm: pm, attr: :assist_tackle)
end

def total_carries(pm)
  safe(pm: pm, attr: :positive_carry) + safe(pm: pm, attr: :carries)
end

def total_aerial_duels(pm)
  safe(pm: pm, attr: :aerial_duel_won) + safe(pm: pm, attr: :aerial_duel_lost)
end

# % Positive Tackles
def positive_tackle_rate(pm)
  tot = total_tackles(pm)
  return 0.0 if tot.zero?
  ((safe(pm: pm, attr: :positive_tackle).to_f / tot) * 100).round(1)
end

def team_avg_positive_tackle_rate(team_pms)
  rates = team_pms.map { |pm| positive_tackle_rate(pm) }.reject(&:zero?)
  return 0.0 if rates.empty?
  (rates.sum / rates.size).round(1)
end



end
