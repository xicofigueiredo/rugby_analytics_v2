module SportHelper
  def sport_process_match_csv(csv_data)
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
        player = Player.find_by(name: player_name, team_id: current_user.team_id)

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
          sport_create_actions_from_stats(player_match, row, csv_data.headers, index)
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
        teamstat = sport_create_team_stats(match, team_stats_data)
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
      sport_calculate_team_average(match)

      # Calculate Python-based ratings for all players
      Rails.logger.info "Calculating Python-based ratings for match #{match.id}"
      begin
        SportPythonRatingService.new(match).calculate_all_ratings!
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

  def sport_create_actions_from_stats(player_match, row, headers, index)
    # Map CSV columns to PlayerMatch field names based on your actual CSV format
    field_mapping = {
      'MIN' => 'time_played',
      'ENSAIOS' => 'try',
      'AMARELOS' => 'yellow',
      'VERMELHOS' => 'red',
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
      'CARRIES' => 'carries',
      'PONTOS EXTRA' => 'extra_points'
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

  def sport_create_team_stats(match, team_stats_data)
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

  def sport_calculate_team_average(match)
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
end
