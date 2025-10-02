class PlayerRatingService
  def initialize(player_match)
    @player_match = player_match
  end

  def calculate_all_ratings!
    @player_match.update!(
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
    # Point system for attack
    tries_points = (@player_match.try || 0) * 2.0        # Max ~6 points (3 tries)
    assists_points = (@player_match.try_assist || 0) * 1.5  # Max ~3 points (2 assists)
    linebreak_points = (@player_match.linebreak || 0) * 0.5  # Max ~2 points (4 linebreaks)

    # Carry effectiveness
    total_carries = (@player_match.carries || 0) + (@player_match.positive_carry || 0)
    carries_points = (@player_match.positive_carry || 0) * 0.1  # Max ~2 points (20 positive carries)
    carry_effectiveness = total_carries > 0 ? ((@player_match.positive_carry || 0).to_f / total_carries * 100) : 0
    carry_bonus = (carry_effectiveness / 100.0) * 1.0  # Max 1 point for 100% effectiveness

    total_points = tries_points + assists_points + linebreak_points + carries_points + carry_bonus
    # Cap at 10 and ensure minimum of 0
    [[total_points, 10.0].min, 0.0].max.round(2)
  end

  def calculate_defense_rating
    # Point system for defense
    positive_tackles_points = (@player_match.positive_tackle || 0) * 0.4  # Max ~4 points (10 tackles)
    neutral_tackles_points = (@player_match.neutral_tackle || 0) * 0.2   # Max ~2 points (10 tackles)
    negative_tackles_points = (@player_match.negative_tackle || 0) * 0.1  # Max ~1 point (10 tackles)

    total_tackles = (@player_match.positive_tackle || 0) + (@player_match.neutral_tackle || 0) + (@player_match.negative_tackle || 0)
    tackle_points = positive_tackles_points + neutral_tackles_points + negative_tackles_points

    # Tackle success bonus (max 2 points)
    total_attempts = total_tackles + (@player_match.missed_tackle || 0)
    success_rate = total_attempts > 0 ? (total_tackles.to_f / total_attempts * 100) : 0
    success_bonus = (success_rate / 100.0) * 2.0

    # Turnover points (max ~2 points for 1-2 turnovers)
    turnover_points = (@player_match.turnover || 0) * 1.0
    assist_points = (@player_match.assist_tackle || 0) * 0.1  # Max ~1 point (10 assists)

    total_points = tackle_points + success_bonus + turnover_points + assist_points
    # Cap at 10 and ensure minimum of 0
    [[total_points, 10.0].min, 0.0].max.round(2)
  end

  def calculate_consistency_rating
    # Tackle consistency (0-2.5 points)
    total_tackles = (@player_match.positive_tackle || 0) + (@player_match.neutral_tackle || 0) + (@player_match.negative_tackle || 0)
    total_attempts = total_tackles + (@player_match.missed_tackle || 0)
    tackle_consistency = total_attempts > 0 ? (total_tackles.to_f / total_attempts * 100) : 0
    tackle_points = (tackle_consistency / 100.0) * 2.5

    # Ball handling consistency (0-2.5 points) - low error rate = high points
    total_ball_contacts = (@player_match.carries || 0) + (@player_match.try_assist || 0)
    error_rate = total_ball_contacts > 0 ? ((@player_match.knock_on || 0).to_f / total_ball_contacts * 100) : 0
    handling_points = ((100 - error_rate) / 100.0) * 2.5
    handling_points = [handling_points, 0].max

    # Offload consistency (0-2 points)
    total_offloads = (@player_match.positive_offload || 0) + (@player_match.negative_offload || 0)
    offload_consistency = total_offloads > 0 ? ((@player_match.positive_offload || 0).to_f / total_offloads * 100) : 50
    offload_points = (offload_consistency / 100.0) * 2.0

    # Aerial consistency (0-1.5 points)
    total_air_duels = (@player_match.aerial_duel_won || 0) + (@player_match.aerial_duel_lost || 0)
    aerial_consistency = total_air_duels > 0 ? ((@player_match.aerial_duel_won || 0).to_f / total_air_duels * 100) : 50
    aerial_points = (aerial_consistency / 100.0) * 1.5

    # Kicking consistency (0-1.5 points)
    penalty_made = (@player_match.penalty_kick_goal || 0)
    penalty_missed = (@player_match.missed_penalty_kick_goals || 0)
    conversion_made = (@player_match.conversion || 0)
    conversion_missed = (@player_match.missed_conversion || 0)
    drop_made = (@player_match.drop_goal || 0)
    drop_missed = (@player_match.missed_drop_goals || 0)

    total_kicks_attempted = penalty_made + penalty_missed + conversion_made + conversion_missed + drop_made + drop_missed
    total_kicks_made = penalty_made + conversion_made + drop_made

    kicking_consistency = if total_kicks_attempted > 0
                           (total_kicks_made.to_f / total_kicks_attempted * 100)
                         else
                           50 # Neutral score for non-kickers
                         end
    kicking_points = (kicking_consistency / 100.0) * 1.5

    total_points = tackle_points + handling_points + offload_points + aerial_points + kicking_points
    # Cap at 10 and ensure minimum of 0
    [[total_points, 10.0].min, 0.0].max.round(2)
  end

  def calculate_discipline_rating
    # Start with perfect score of 10
    base_score = 10.0

    # Penalties reduce score (each penalty = -1 point)
    penalty_penalty = total_penalties * -1.0
    yellow_penalty = (@player_match.yellow || 0) * -3.0  # Yellow card = -3 points
    red_penalty = (@player_match.red || 0) * -5.0        # Red card = -5 points
    knock_on_penalty = (@player_match.knock_on || 0) * -0.5  # Knock-on = -0.5 points

    discipline_points = base_score + penalty_penalty + yellow_penalty + red_penalty + knock_on_penalty
    # Cap at 10 and ensure minimum of 0
    [[discipline_points, 10.0].min, 0.0].max.round(2)
  end

  def calculate_skills_rating
    # Skills points (designed to max out around 10)
    offload_points = (@player_match.positive_offload || 0) * 2.0    # Max ~4 points (2 good offloads)
    offload_penalty = (@player_match.negative_offload || 0) * -1.0  # Penalty for bad offloads

    aerial_points = (@player_match.aerial_duel_won || 0) * 1.0      # Max ~3 points (3 aerial wins)
    aerial_penalty = (@player_match.aerial_duel_lost || 0) * -0.5   # Penalty for losses

    linebreak_points = (@player_match.linebreak || 0) * 1.5        # Max ~3 points (2 linebreaks)
    assist_points = (@player_match.try_assist || 0) * 2.0          # Max ~4 points (2 assists)

    total_points = offload_points + offload_penalty + aerial_points + aerial_penalty + linebreak_points + assist_points
    # Cap at 10 and ensure minimum of 0
    [[total_points, 10.0].min, 0.0].max.round(2)
  end

  def calculate_work_rate_rating
    # Total involvement (scaled to fit 0-10)
    total_involvement = (
      (@player_match.positive_tackle || 0) + (@player_match.neutral_tackle || 0) + (@player_match.negative_tackle || 0) +
      (@player_match.carries || 0) + (@player_match.positive_carry || 0) +
      (@player_match.try_assist || 0) + (@player_match.assist_tackle || 0)
    )
    involvement_points = total_involvement * 0.15  # Max ~6 points (40 total involvements)

    total_positive = (@player_match.positive_tackle || 0) + (@player_match.positive_carry || 0) + (@player_match.try_assist || 0)
    positive_bonus = total_positive * 0.2  # Max ~4 points (20 positive actions)

    # Note: We don't have minutes played in the current model, so we'll skip the per-minute calculation
    # If you add a minutes field later, you can uncomment this:
    # minutes = @player_match.minutes_played || 80 # default to full game
    # per_minute_bonus = minutes > 0 ? (total_positive.to_f / minutes) * 2 : 0

    total_points = involvement_points + positive_bonus # + per_minute_bonus
    # Cap at 10 and ensure minimum of 0
    [[total_points, 10.0].min, 0.0].max.round(2)
  end

  # Helper method to calculate total penalties
  def total_penalties
    (@player_match.pen_offside || 0) + (@player_match.pen_breakdown || 0) +
    (@player_match.pen_scrum || 0) + (@player_match.pen_others || 0)
  end
end
