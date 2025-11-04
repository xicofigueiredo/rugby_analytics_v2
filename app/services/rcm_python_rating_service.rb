require 'open3'

class RcmPythonRatingService
  def initialize(match)
    @match = match
  end

  def calculate_all_ratings!
    # Get all player matches for this match with valid minutes
    player_matches = @match.player_matches.joins(:player)
                           .where("CAST(time_played AS INTEGER) > 0")
                           .order(:id)

    return if player_matches.empty?

    # Prepare data for Python script
    players_data = player_matches.map do |pm|
      {
        # Basic info
        minutes: (pm.time_played || 0).to_i,

        # Scoring stats
        tries: pm.try || 0,
        assists: pm.try_assist || 0,
        conversions_made: pm.conversion || 0,
        conversions_attempted: (pm.conversion || 0) + (pm.missed_conversion || 0),
        kicks_made: pm.penalty_kick_goal || 0,
        kicks_attempted: (pm.penalty_kick_goal || 0) + (pm.missed_penalty_kick_goals || 0),
        drops_made: pm.drop_goal || 0,
        drops_attempted: (pm.drop_goal || 0) + (pm.missed_drop_goals || 0),

        # Tackle stats
        offensive_tackles: pm.positive_tackle || 0,
        neutral_tackles: pm.neutral_tackle || 0,
        defensive_tackles: pm.negative_tackle || 0,
        assist_tackles: pm.assist_tackle || 0,
        missed_tackles: pm.missed_tackle || 0,

        # Carry stats
        carries_with_gain: pm.positive_carry || 0,
        carries_without_gain: (pm.carries || 0),

        # Other attacking stats
        linebreak: pm.linebreak || 0,
        linebreak_assists: pm.linebreak_assists || 0,
        offloads_good: pm.positive_offload || 0,
        offloads_bad: pm.negative_offload || 0,

        # Defensive stats
        turnovers_won: pm.turnover || 0,

        # Penalty stats
        total_penalties: (pm.pen_offside || 0) + (pm.pen_breakdown || 0) + (pm.pen_scrum || 0) + (pm.pen_others || 0),
        offside_penalties: pm.pen_offside || 0,
        ruck_penalties: pm.pen_breakdown || 0,
        scrum_penalties: pm.pen_scrum || 0,
        other_penalties: pm.pen_others || 0,

        # Mistakes
        knock_on: pm.knock_on || 0,
        other_mistakes: pm.other_mistakes || 0,
        yellow_cards: pm.yellow || 0,
        red_cards: pm.red || 0,

        # Aerial duels
        aerial_duels_won: pm.aerial_duel_won || 0,
        aerial_duels_lost: pm.aerial_duel_lost || 0,

        # Lineout stats
        lineout_steals: pm.lineout_turnover || 0,
        own_lineouts_won: (pm.lineout_won_jump || 0) + (pm.lineout_won_no_jump || 0),
        lineout_intros_won: pm.introduction_won || 0,
        lineout_intros_total: (pm.introduction_won || 0) + (pm.introduction_lost || 0),

        # Scrum stats
        scrum_dominant: pm.scrum_dominant || 0,

        # Mod game stats
        mod_game_plus: pm.mod_game_plus || 0,
        mod_game_minus: pm.mod_game_minus || 0,

        # Extra points for overall rating adjustment
        extra_points: pm.extra_points || 0
      }
    end

    # Call Python script
    begin
      results = call_python_rating_script(players_data)

      # Update player matches with calculated ratings
      results.each do |result|
        next if result['error']

        player_match = player_matches[result['player_index']]
        player_match.update!(
          attack_rating: result['attack_rating'],
          defense_rating: result['defense_rating'],
          discipline_rating: result['discipline_rating'],
          work_rate_rating: result['work_rate_rating'],
          skills_rating: result['skills_rating'],
          consistency_rating: result['consistency_rating'],
          overall_rating: result['overall_rating']
        )
      end

      Rails.logger.info "Successfully calculated ratings for #{results.length} players"

    rescue => e
      Rails.logger.error "Failed to calculate Python ratings: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      # Fallback to simple default ratings if Python fails
      player_matches.each do |pm|
        pm.update!(
          attack_rating: 5.0,
          defense_rating: 5.0,
          discipline_rating: 5.0,
          work_rate_rating: 5.0,
          skills_rating: 5.0,
          consistency_rating: 5.0,
          overall_rating: 5.0
        )
      end
    end
  end

  private

  def call_python_rating_script(players_data)
    # Convert data to JSON
    input_json = players_data.to_json

    # Path to Python script
    python_script_path = Rails.root.join('lib', 'tasks', 'sport_rating_system_v1.py')

    # Determine Python executable based on environment
    if Rails.env.development? || Rails.env.test?
      # In development, prefer local virtual environment if available
      venv_python_path = Rails.root.join('venv', 'bin', 'python')
      python_executable = File.exist?(venv_python_path) ? venv_python_path.to_s : "python3"
    else
      # In production (Docker), use Docker virtual environment or system python3
      docker_venv_python = "/opt/venv/bin/python"
      python_executable = File.exist?(docker_venv_python) ? docker_venv_python : "python3"
    end

    # Log the Python executable being used
    Rails.logger.info "Using Python executable: #{python_executable}"
    Rails.logger.info "Python script path: #{python_script_path}"

    # Execute Python script
    result = nil
    Open3.popen3(python_executable, python_script_path.to_s) do |stdin, stdout, stderr, wait_thr|
      # Send JSON data to Python script
      stdin.write(input_json)
      stdin.close

      # Read result
      output = stdout.read
      error_output = stderr.read

      if wait_thr.value.success?
        result = JSON.parse(output)
      else
        # Provide specific error messages for common issues
        if error_output.include?("ModuleNotFoundError: No module named 'pandas'")
          raise "Python pandas module not installed. Please install pandas: pip3 install pandas"
        elsif error_output.include?("ModuleNotFoundError: No module named 'numpy'")
          raise "Python numpy module not installed. Please install numpy: pip3 install numpy"
        elsif error_output.include?("python3: command not found") || error_output.include?("python: command not found")
          raise "Python not found. Please install Python 3"
        else
          raise "Python script failed (exit code: #{wait_thr.value.exitstatus}): #{error_output}"
        end
      end
    end

    result
  end
end
