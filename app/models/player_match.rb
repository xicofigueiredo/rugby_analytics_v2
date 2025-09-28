class PlayerMatch < ApplicationRecord
  belongs_to :match
  belongs_to :player
  has_many :actions, dependent: :destroy

  # Add both types of notes
  validates :coach_notes, length: { maximum: 1000 } # adjust max length as needed
  validates :player_notes, length: { maximum: 1000 } # adjust max length as needed

  # Helper methods for statistics using direct fields
  def total_actions
    # Sum all positive action fields
    (try || 0) + (conversion || 0) + (penalty_kick_goal || 0) + (drop_goal || 0) +
    (try_assist || 0) + (positive_tackle || 0) + (neutral_tackle || 0) +
    (assist_tackle || 0) + (lineout_turnover || 0) + (lineout_won_jump || 0) +
    (lineout_won_no_jump || 0) + (introduction_won || 0) + (turnover || 0) +
    (aerial_duel_won || 0) + (positive_offload || 0) + (linebreak || 0) +
    (positive_carry || 0) + (carries || 0)
  end

  def positive_actions_count
    # Sum positive actions
    (try || 0) + (conversion || 0) + (penalty_kick_goal || 0) + (drop_goal || 0) +
    (try_assist || 0) + (positive_tackle || 0) + (neutral_tackle || 0) +
    (assist_tackle || 0) + (lineout_turnover || 0) + (lineout_won_jump || 0) +
    (lineout_won_no_jump || 0) + (introduction_won || 0) + (turnover || 0) +
    (aerial_duel_won || 0) + (positive_offload || 0) + (linebreak || 0) +
    (positive_carry || 0) + (carries || 0)
  end

  def negative_actions_count
    # Sum negative actions
    (missed_conversion || 0) + (missed_penalty_kick_goals || 0) + (missed_drop_goals || 0) +
    (negative_tackle || 0) + (missed_tackle || 0) + (introduction_lost || 0) +
    (pen_offside || 0) + (pen_breakdown || 0) + (pen_scrum || 0) + (pen_others || 0) +
    (aerial_duel_lost || 0) + (negative_offload || 0) + (knock_on || 0) +
    (yellow || 0) + (red || 0)
  end

  def tries_scored
    try || 0
  end

  def assists
    try_assist || 0
  end

  def tackles_made
    (positive_tackle || 0) + (neutral_tackle || 0) + (negative_tackle || 0) + (assist_tackle || 0)
  end

  def tackles_missed
    missed_tackle || 0
  end

  def cards_received
    (yellow || 0) + (red || 0)
  end

  def penalties_conceded
    (pen_offside || 0) + (pen_breakdown || 0) + (pen_scrum || 0) + (pen_others || 0)
  end

  def total_offloads
    (positive_offload || 0) + (negative_offload || 0)
  end

  def total_aerial_duels
    (aerial_duel_won || 0) + (aerial_duel_lost || 0)
  end

  def lineout_success_rate
    total_lineouts = (lineout_won_jump || 0) + (lineout_won_no_jump || 0)
    return 0 if total_lineouts == 0
    100.0 # All recorded lineouts are won
  end
end
