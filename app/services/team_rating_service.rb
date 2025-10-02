class TeamRatingService
  def initialize(teamstat)
    @teamstat = teamstat
  end

  def calculate_all_ratings!
    @teamstat.update!(
      attack_rating: calculate_attack_rating,
      defense_rating: calculate_defense_rating,
      consistency_rating: calculate_consistency_rating,
      discipline_rating: calculate_discipline_rating,
      skills_rating: calculate_skills_rating,
      work_rate_rating: calculate_work_rate_rating
    )
  end

  private

  def calculate_attack_rating
    total_points = 0.0
    count = 0

    @teamstat.match.player_matches.each do |player_match|
      if player_match.player.team_id == @teamstat.team_id && (player_match.time_played.to_i > 0)
        total_points += (player_match.attack_rating || 0)
        count += 1
      end
    end

    return 5.0 if count == 0 # Default neutral rating if no players
    average = total_points / count
    [[average, 10.0].min, 0.0].max.round(2)
  end

  def calculate_defense_rating
    total_points = 0.0
    count = 0

    @teamstat.match.player_matches.each do |player_match|
      if player_match.player.team_id == @teamstat.team_id && (player_match.time_played.to_i > 0)
        total_points += (player_match.defense_rating || 0)
        count += 1
      end
    end

    return 5.0 if count == 0 # Default neutral rating if no players
    average = total_points / count
    [[average, 10.0].min, 0.0].max.round(2)
  end

  def calculate_consistency_rating
    total_points = 0.0
    count = 0

    @teamstat.match.player_matches.each do |player_match|
      if player_match.player.team_id == @teamstat.team_id && (player_match.time_played.to_i > 0)
        total_points += (player_match.consistency_rating || 0)
        count += 1
      end
    end

    return 5.0 if count == 0 # Default neutral rating if no players
    average = total_points / count
    [[average, 10.0].min, 0.0].max.round(2)
  end

  def calculate_discipline_rating
    total_points = 0.0
    count = 0

    @teamstat.match.player_matches.each do |player_match|
      if player_match.player.team_id == @teamstat.team_id && (player_match.time_played.to_i > 0)
        total_points += (player_match.discipline_rating || 0)
        count += 1
      end
    end

    return 5.0 if count == 0 # Default neutral rating if no players
    average = total_points / count
    [[average, 10.0].min, 0.0].max.round(2)
  end

  def calculate_skills_rating
    total_points = 0.0
    count = 0

    @teamstat.match.player_matches.each do |player_match|
      if player_match.player.team_id == @teamstat.team_id && (player_match.time_played.to_i > 0)
        total_points += (player_match.skills_rating || 0)
        count += 1
      end
    end

    return 5.0 if count == 0 # Default neutral rating if no players
    average = total_points / count
    [[average, 10.0].min, 0.0].max.round(2)
  end

  def calculate_work_rate_rating
    total_points = 0.0
    count = 0

    @teamstat.match.player_matches.each do |player_match|
      if player_match.player.team_id == @teamstat.team_id && (player_match.time_played.to_i > 0)
        total_points += (player_match.work_rate_rating || 0)
        count += 1
      end
    end

    return 5.0 if count == 0 # Default neutral rating if no players
    average = total_points / count
    [[average, 10.0].min, 0.0].max.round(2)
  end
end
