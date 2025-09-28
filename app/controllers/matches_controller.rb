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
        "Tackles" => (@player_match.positive_tackle || 0) + (@player_match.neutral_tackle || 0) + (@player_match.negative_tackle || 0) + (@player_match.assist_tackle || 0),
        "Missed Tackles" => @player_match.missed_tackle || 0,
        "Turnovers" => @player_match.turnover || 0,
        "Penalties" => (@player_match.pen_offside || 0) + (@player_match.pen_breakdown || 0) + (@player_match.pen_scrum || 0) + (@player_match.pen_others || 0),
        "Offloads" => (@player_match.positive_offload || 0) + (@player_match.negative_offload || 0),
        "Linebreaks" => @player_match.linebreak || 0,
        "Knock-ons" => @player_match.knock_on || 0,
        "Carries" => @player_match.carries || 0,
        "Cards" => (@player_match.yellow || 0) + (@player_match.red || 0),
      }

      player_matches = @match.player_matches
      player_count = player_matches.count.to_f

      @average_player_performance_data = {
        "Tackles" => player_matches.sum { |pm| (pm.positive_tackle || 0) + (pm.neutral_tackle || 0) + (pm.negative_tackle || 0) + (pm.assist_tackle || 0) } / player_count,
        "Missed Tackles" => player_matches.sum { |pm| pm.missed_tackle || 0 } / player_count,
        "Turnovers" => player_matches.sum { |pm| pm.turnover || 0 } / player_count,
        "Penalties" => player_matches.sum { |pm| (pm.pen_offside || 0) + (pm.pen_breakdown || 0) + (pm.pen_scrum || 0) + (pm.pen_others || 0) } / player_count,
        "Offloads" => player_matches.sum { |pm| (pm.positive_offload || 0) + (pm.negative_offload || 0) } / player_count,
        "Linebreaks" => player_matches.sum { |pm| pm.linebreak || 0 } / player_count,
        "Knock-ons" => player_matches.sum { |pm| pm.knock_on || 0 } / player_count,
        "Carries" => player_matches.sum { |pm| pm.carries || 0 } / player_count,
        "Cards" => player_matches.sum { |pm| (pm.yellow || 0) + (pm.red || 0) } / player_count,
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
          Rails.logger.info "FO GANHAS SPORT: '#{row['FO GANHAS SPORT']}'"
          Rails.logger.info "FO TOTAIS SPORT: '#{row['FO TOTAIS SPORT']}'"
          Rails.logger.info "FO GANHAS ADVERSARIO: '#{row['FO GANHAS ADVERSARIO']}'"
          Rails.logger.info "FO TOTAIS ADVERSARIO: '#{row['FO TOTAIS ADVERSARIO']}'"

          lineouts_ganhos_sport = safe_to_i.call(row['ALINHAMENTO GANHOS SPORT'])
          lineouts_totais_sport = safe_to_i.call(row['ALINHAMENTO TOTAIS SPORT'])
          lineouts_ganhos_adversario = safe_to_i.call(row['ALINHAMENTO GANHOS ADVERSARIO'])
          lineouts_totais_adversario = safe_to_i.call(row['ALINHAMENTO TOTAIS ADVERSARIO'])
          scrums_ganhos_sport = safe_to_i.call(row['FO GANHAS SPORT'])
          scrums_totais_sport = safe_to_i.call(row['FO TOTAIS SPORT'])
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
end
