module RcmHelper
  def rcm_process_match_csv(csv_data)
    Rails.logger.info "rcm_process_match_csv called with #{csv_data.count} rows"
    return if csv_data.empty?

    ActiveRecord::Base.connection.verify!

    ActiveRecord::Base.transaction do
      # Structure of RCM CSV:
      # - Row 0 (index 0): metadata row with match info on the far right (uses headers from line 1)
      # - Row 1 (index 1): second header row with detailed stat column names (we'll use these as headers)
      # - Rows 2+        : player data rows aligned with the second header row
      meta_row = csv_data[0]
      second_header_row = csv_data[1]
      raise "CSV missing second header row with detailed stats" if second_header_row.nil?

      # Extract match info from meta row using the first header row names
      date_str = meta_row.to_h['DATA']&.strip
      home_team_name = meta_row.to_h['EQUIPA CASA']&.strip
      away_team_name = meta_row.to_h['EQUIPA FORA']&.strip
      home_points = meta_row.to_h['PONTOS CASA']&.to_s&.strip
      away_points = meta_row.to_h['PONTOS FORA']&.to_s&.strip
      result = "#{home_points} - #{away_points}" if home_points.present? && away_points.present?
      competition = meta_row.to_h['COMPETIÇÃO']&.strip
      season = Date.current.year.to_s

      Rails.logger.info "RCM Extracted match data: date='#{date_str}', home='#{home_team_name}', away='#{away_team_name}', comp='#{competition}', result='#{result}'"

      # Parse date like "7-nov." or "7-nov"
      begin
        cleaned_date = date_str.to_s.gsub('.', '').gsub('/', '-').strip
        if cleaned_date.match?(/\A\d{1,2}-[A-Za-z]{3,}\z/)
          date = Date.parse("#{cleaned_date}-#{Date.current.year}")
        else
          date = Date.parse(cleaned_date)
        end
      rescue Date::Error
        date = Date.current
      end

      raise "Invalid team names in CSV" if home_team_name.blank? || away_team_name.blank?

      home_team = Team.find_or_create_by!(name: home_team_name) do |team|
        team.level = 'Senior'
        team.classification = 5
        team.main_color = '#000000'
        team.secondary_color = '#000000'
      end
      away_team = Team.find_or_create_by!(name: away_team_name) do |team|
        team.level = 'Senior'
        team.classification = 5
        team.main_color = '#000000'
        team.secondary_color = '#000000'
      end

      existing_match = Match.find_by(
        date: date,
        home_team: home_team,
        away_team: away_team,
        result: result,
        competition: competition,
        season: season
      )
      raise "Match already exists: #{home_team.name} vs #{away_team.name} on #{date}" if existing_match

      match = Match.create!(
        season: season,
        competition: competition,
        date: date,
        home_team_id: home_team.id,
        away_team_id: away_team.id,
        result: result
      )

      # Build the detailed headers from the second header row (index 1)
      # We'll use these as column names for subsequent player rows
      rcm_headers = second_header_row.fields.map { |h| h.to_s.strip }
      Rails.logger.info "RCM detailed headers count: #{rcm_headers.size}"

      team_stats_data = nil
      players_processed = 0

      # Iterate player rows starting at index 2
      csv_data.each_with_index do |row, row_index|
        next if row_index < 2

        values = row.fields
        # Build a hash: detailed_header -> cell_value
        row_by_header = {}
        rcm_headers.each_with_index do |hdr, i|
          row_by_header[hdr] = values[i]
        end

        player_name = values[1].to_s.strip # Column2 is 'Nome'
        # Skip invalid/empty rows
        if player_name.blank? || player_name.upcase.include?('TOTAL') || player_name == 'Nome'
          next
        end

        # Capture team stats once (same on every row)
        if team_stats_data.nil?
          team_stats_data = rcm_extract_team_stats(row_by_header)
          Rails.logger.info "RCM team stats extracted: #{team_stats_data.inspect}"
        end

        player = Player.find_by(name: player_name, team_id: current_user.team_id)
        unless player
          Rails.logger.warn "Player '#{player_name}' not found (RCM), skipping"
          next
        end

        players_processed += 1
        player_match = match.player_matches.create!(
          player: player,
          position: players_processed,
          started: players_processed <= 15
        )

        rcm_create_actions_from_stats(player_match, row_by_header)
      end

      if team_stats_data
        teamstat = rcm_create_team_stats(match, team_stats_data)
        begin
          teamstat.calculate_ratings!
        rescue => e
          Rails.logger.error "RCM team ratings failed: #{e.message}"
        end
      end

      # Reuse the same averaging logic
      sport_calculate_team_average(match)

      # Python-based ratings
      begin
        RcmPythonRatingService.new(match).calculate_all_ratings!
      rescue => e
        Rails.logger.error "RCM python ratings failed: #{e.message}"
      end
    end
  end

  def rcm_create_actions_from_stats(player_match, row_by_header)
    # Safe integer conversion
    to_i = ->(v) { v.to_s.strip.to_i }

    # Map RCM column names (second header row) to PlayerMatch fields
    mapping = {
      'MINUTOS' => 'time_played',
      'Ensaio' => 'try',
      'Assistência' => 'try_assist',
      'Conversão de ensaio acertada' => 'conversion',
      'Conversão de ensaio falhada' => 'missed_conversion',
      'Chuto Pen (3pts) convertido' => 'penalty_kick_goal',
      'Chuto Pen (3pts) falhado' => 'missed_penalty_kick_goals',
      'Drop Convertido' => 'drop_goal',
      'Drop Falhado' => 'missed_drop_goals',

      'Placagem a dois' => 'assist_tackle',
      'Placagem Efetiva' => 'positive_tackle',
      'Placagem neutra' => 'neutral_tackle',
      'Placagem a recuar' => 'negative_tackle',
      'Placagem falhada' => 'missed_tackle',

      'Turnover feito' => 'turnover',
      'Interceção feita' => 'interception',
      'Receção do ar-' => nil,
      'ruck clear' => 'ruck_clear',
      'Ruck Seal' => 'ruck_seal',
      'Penalidades a defender' => 'pen_defense',
      'Carrie Positiva' => 'positive_carry',
      'Carrie Neutra' => 'neutral_carry',
      'Carrie a recuar' => 'negative_carry',
      'Passe +' => 'good_pass',
      'Passe -' => 'bad_pass',
      'Chuto' => 'kick',
      'Interceção Sofrida' => 'given_interception',
      'Turnover sofrido' => 'given_turnover',
      'Defesas batidos' => 'defenders_beaten',
      'Penalidades Ataque' => 'atack_penalties',
      'Erros não forçados' => 'unforced_errors',
      'Accurate throw' => 'introduction_won',
      'Inaccurate throw' => 'introduction_lost',
      'Lineout ganha' => 'lineout_won',
      'Lineout perdida' => 'lineout_lost',
      'Kick pass' => 'kick_pass',
      'Receção de bola no ar' => nil,
      'Drop de inicio on target' => 'drop_on_target',
      'Drop de inicio off target' => 'drop_off_target',
      'Erro forçado ao adversário' => 'forced_an_error',
      'Fora do sitio' => 'misplaced',
      'Pick&Go +' => 'positive_pick',
      'Pick&Go -' => 'negative_pick',



      'Ruck perdido' => 'ruck_lost',
      'Duelo aéreo ganho' => 'aerial_duel_won',
      'Duelo aéreo perdido' => 'aerial_duel_lost',
      'Offload' => 'positive_offload',
      'Offload menos' => 'negative_offload',
      'Linebreak' => 'linebreak',
      'Linebreak assist' => 'linebreak_assists',
      'Avant' => 'knock_on',

      'Extra' => 'extra_points',
      'Cartão Amarelo' => 'yellow',
      'Cartão Vermelho' => 'red',
      'Plano de Jogo +' => 'mod_game_plus',
      'Plano de Jogo -' => 'mod_game_minus'
    }

    update_attrs = {}
    mapping.each do |rcm_col, pm_field|
      next if pm_field.nil?
      val = row_by_header[rcm_col]
      next if val.blank?
      update_attrs[pm_field] = to_i.call(val)
    end

    # Penalidades (defense + attack) mapped into pen_others to count totals
    pen_def = to_i.call(row_by_header['Penalidades a defender'])
    pen_atk = to_i.call(row_by_header['Penalidades Ataque'])
    total_pens = pen_def + pen_atk
    update_attrs['pen_others'] = (update_attrs['pen_others'] || 0) + total_pens if total_pens > 0

    # Persist updates
    player_match.update!(update_attrs) if update_attrs.any?
  end

  def rcm_extract_team_stats(row_by_header)
    to_i = ->(v) { v.to_s.strip.to_i }

    lineouts_won = to_i.call(row_by_header['Alinhamento Próprio Ganho'])
    lineouts_lost = to_i.call(row_by_header['Alinhamento Próprio Perdido'])
    lineouts_stolen = to_i.call(row_by_header['Alinhamento Adversário Ganha'])
    lineouts_not_stolen = to_i.call(row_by_header['Alinhamento Adversário Perdido'])

    scrums_won = to_i.call(row_by_header['FO Própria ganha'])
    scrums_lost = to_i.call(row_by_header['FO Própria perdida'])
    scrums_stolen = to_i.call(row_by_header['FO Adversária Ganha'])
    scrums_not_stolen = to_i.call(row_by_header['FO Adversária Perdida'])

    {
      lineouts_won: lineouts_won,
      lineouts_lost: lineouts_lost,
      lineouts_stolen: lineouts_stolen,
      lineouts_not_stolen: lineouts_not_stolen,
      scrums_won: scrums_won,
      scrums_lost: scrums_lost,
      scrums_stolen: scrums_stolen,
      scrums_not_stolen: scrums_not_stolen
    }
  end

  def rcm_create_team_stats(match, team_stats_data)
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
    teamstat
  end
end
