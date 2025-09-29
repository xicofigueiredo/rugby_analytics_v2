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
    @team = current_user.team
    @players = PlayerMatch.where(match_id: @match.id)
    @starting_players = @players.where(started: true)
    @bench_players = @players.where(started: false)
    @scorer_players = @players.where("try > 0 OR conversion > 0 OR penalty_kick_goal > 0 OR drop_goal > 0")
    @player_match = PlayerMatch.where(match_id: @match.id, player_id: current_user.player_id).first
    @player = current_user.player
    @staff = @team.users.where.not(role: ["player", "fan"])
    calculate_top_players(@match)

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
    away_team_id = @match.away_team_id

    # Check if user's team was playing at home or away
    user_team_is_home = (user_team_id == home_team_id)
    user_team_has_stats = (user_team_id == stats_team_id)

    # Get team names
    home_team_name = @match.home_team.name
    away_team_name = @match.away_team.name

    if user_team_has_stats
      # We have stats for user's team - show from their perspective
      if user_team_is_home
        # User's team is home (left side)
        user_team_percentage = lineouts_percentage
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

    if current_user.team.name == "SPORT"
      @performance_data = {
        "Tackles Made" => @player_match.tackles_made,
        "Missed Tackles" => @player_match.missed_tackle,
        "Turnovers" => @player_match.turnover,
        "Penalties" => @player_match.penalties_conceded,
        "Positive Offloads" => @player_match.positive_offload,
        "Negative Offloads" => @player_match.negative_offload,
        "Linebreaks" => @player_match.linebreak,
        "Knock-ons" => @player_match.knock_on,
        "Positive Carries" => @player_match.positive_carry,
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

    else
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
      "positive_tackles" => @positive_tackles_top_players.map { |pm| { name: pm.player.name, value: pm.positive_tackle || 0 } },
      "turnovers" => @turnovers_top_players.map { |pm| { name: pm.player.name, value: pm.turnover || 0 } },
      "penalties" => @penalties_top_players.map { |pm| { name: pm.player.name, value: pm.total_penalties || 0 } },
      "carries" => @carries_top_players.map { |pm| { name: pm.player.name, value: pm.carries || 0 } },
      "positive_carries" => @positive_carries_top_players.map { |pm| { name: pm.player.name, value: pm.positive_carry || 0 } },
      "positive_offloads" => @positive_offloads_top_players.map { |pm| { name: pm.player.name, value: pm.positive_offload || 0 } },
      "linebreaks" => @linebreaks_top_players.map { |pm| { name: pm.player.name, value: pm.linebreak || 0 } }
    }

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
      # Read CSV with semicolon delimiter since the file uses ';' not ','
      csv_data = CSV.read(uploaded_file.path, headers: true, col_sep: ';')
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

    ActiveRecord::Base.transaction do
      # Get match data from first row (excluding totals)
      first_row = csv_data.first

      # Extract match information from the row - using correct column names from your CSV
      date_str = first_row['DATA']&.strip
      home_team_name = first_row['EQUIPA CASA']&.strip
      away_team_name = first_row['EQUIPA FORA']&.strip
      home_points = first_row['PONTOS CASA']&.strip
      away_points = first_row['PONTOS FORA']&.strip
      result = "#{home_points} - #{away_points}" if home_points.present? && away_points.present?
      competition = first_row['COMPETIÇÃO']&.strip
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

      # Debug: Print CSV headers
      Rails.logger.info "CSV Headers: #{csv_data.headers}"

      csv_data.each_with_index do |row, index|
        player_name = row['NOME']&.strip

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
          Rails.logger.info "ALINHAMENTO GANHOS SPORT: '#{row['ALINHAMENTO GANHOS SPORT']}'"
          Rails.logger.info "ALINHAMENTO TOTAIS SPORT: '#{row['ALINHAMENTO TOTAIS SPORT']}'"
          Rails.logger.info "ALINHAMENTO GANHOS ADVERSARIO: '#{row['ALINHAMENTO GANHOS ADVERSARIO']}'"
          Rails.logger.info "ALINHAMENTO TOTAIS ADVERSARIO: '#{row['ALINHAMENTO TOTAIS ADVERSARIO']}'"
          Rails.logger.info "FO GANHAS SPORT: '#{row['FO GANHAS SPORT ']}'"
          Rails.logger.info "FO TOTAIS SPORT: '#{row['FO TOTAIS SPORT ']}'"
          Rails.logger.info "FO GANHAS ADVERSARIO: '#{row['FO GANHAS ADVERSARIO']}'"
          Rails.logger.info "FO TOTAIS ADVERSARIO: '#{row['FO TOTAIS ADVERSARIO']}'"

          lineouts_ganhos_sport = safe_to_i.call(row['ALINHAMENTO GANHOS SPORT'])
          lineouts_totais_sport = safe_to_i.call(row['ALINHAMENTO TOTAIS SPORT'])
          lineouts_ganhos_adversario = safe_to_i.call(row['ALINHAMENTO GANHOS ADVERSARIO'])
          lineouts_totais_adversario = safe_to_i.call(row['ALINHAMENTO TOTAIS ADVERSARIO'])
          scrums_ganhos_sport = safe_to_i.call(row['FO GANHAS SPORT '])
          scrums_totais_sport = safe_to_i.call(row['FO TOTAIS SPORT '])
          scrums_ganhos_adversario = safe_to_i.call(row['FO GANHAS ADVERSARIO'])
          scrums_totais_adversario = safe_to_i.call(row['FO TOTAIS ADVERSARIO'])

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
          next
        end

        # Create player match with error handling
        begin
          player_match = match.player_matches.create!(player: player)
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.error "Failed to create player_match for '#{player_name}': #{e.message}"
          next
        end

        # Create actions based on stats with error handling
        begin
          create_actions_from_stats(player_match, row, csv_data.headers, index)
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.error "Failed to create stats for player '#{player_name}': #{e.message}"
          # Continue processing other players even if one fails
        end
      end

      # Create team stats after processing all players
      create_team_stats(match, team_stats_data) if team_stats_data
      calculate_team_average(match)
    end # End transaction
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
      'RECUPERAÇÃO AL.' => 'lineout_turnover',
      'AL. SPORT COM SALTO' => 'lineout_won_jump',
      'AL. SPORT SEM SALTO' => 'lineout_won_no_jump',
      'INTRODUÇÕES GANHAS' => 'introduction_won',
      'INTRODUÇÕES TOTAIS' => nil, # We calculate lost as total - won
      'TURNOVERS' => 'turnover',
      'PEN - Fora de Jogo' => 'pen_offside',
      'PEN - Jogo no Chão' => 'pen_breakdown',
      'PEN - F.O.' => 'pen_scrum',
      'PEN - Outros' => 'pen_others',
      'DUELOS AEREOS (+)' => 'aerial_duel_won',
      'DUELOS AEREOS (–)' => 'aerial_duel_lost',
      'OFFLOADS (+)' => 'positive_offload',
      'OFFLOADS (–)' => 'negative_offload',
      'QUEBRAS DE LINHA' => 'linebreak',
      'AVANTS' => 'knock_on',
      'CARRIES (+)' => 'positive_carry',
      'CARRIES' => 'carries'
    }

    # Update player_match with stats from CSV
    update_attributes = {}

    if index < 16
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
    introduções_totais = row['INTRODUÇÕES TOTAIS'].to_s.strip.to_i
    introduções_ganhas = row['INTRODUÇÕES GANHAS'].to_s.strip.to_i
    if introduções_totais > 0 && introduções_ganhas >= 0
      update_attributes['introduction_lost'] = introduções_totais - introduções_ganhas
    end

    # Handle missed conversions if we have totals
    conversões_totais = row['CONVERSÕES TOTAL'].to_s.strip.to_i
    conversões_feitas = row['CONVERSÕES FEITAS'].to_s.strip.to_i
    if conversões_totais > 0 && conversões_feitas >= 0
      update_attributes['missed_conversion'] = conversões_totais - conversões_feitas
    end

    # Handle missed penalty kicks if we have totals
    pen_totais = row['PEN POSTES TOTAL'].to_s.strip.to_i
    pen_convertidas = row['PEN POSTES CONVERTIDAS'].to_s.strip.to_i
    if pen_totais > 0 && pen_convertidas >= 0
      update_attributes['missed_penalty_kick_goals'] = pen_totais - pen_convertidas
    end

    # Handle missed drops if we have totals
    drops_totais = row['DROPS TOTAL'].to_s.strip.to_i
    drops_convertidos = row['DROPS CONVERTIDOS'].to_s.strip.to_i
    if drops_totais > 0 && drops_convertidos >= 0
      update_attributes['missed_drop_goals'] = drops_totais - drops_convertidos
    end

    # Update the player_match with all the stats
    player_match.update!(update_attributes) if update_attributes.any?
  end

  def create_team_stats(match, team_stats_data)
    # Create home team stats (the stats appear to be for the home team based on CSV structure)
    home_teamstat = match.teamstat.create!(
      team_id: match.home_team.id,
      lineouts_won: team_stats_data[:lineouts_won],
      lineouts_lost: team_stats_data[:lineouts_lost],
      lineouts_stolen: team_stats_data[:lineouts_stolen],
      lineouts_not_stolen: team_stats_data[:lineouts_not_stolen],
      scrums_won: team_stats_data[:scrums_won],
      scrums_lost: team_stats_data[:scrums_lost],
      scrums_stolen: team_stats_data[:scrums_stolen],
      scrums_not_stolen: team_stats_data[:scrums_not_stolen]
    )

    Rails.logger.info "Created home team stats: #{home_teamstat.inspect}"
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

end
