class PlayerMatch < ApplicationRecord
  belongs_to :match
  belongs_to :player
  has_many :actions, dependent: :destroy

  # Add both types of notes
  validates :coach_notes, length: { maximum: 1000 } # adjust max length as needed
  validates :player_notes, length: { maximum: 1000 } # adjust max length as needed

  def tackles_made
    (positive_tackle || 0) + (neutral_tackle || 0) + (negative_tackle || 0) + (assist_tackle || 0)
  end

  def penalties_conceded
    (pen_offside || 0) + (pen_breakdown || 0) + (pen_scrum || 0) + (pen_others || 0)
  end

  # Rating calculation methods
  def calculate_ratings!
    PlayerRatingService.new(self).calculate_all_ratings!
  end

  def has_ratings?
    [attack_rating, defense_rating, consistency_rating, discipline_rating, skills_rating, work_rate_rating].any?(&:present?)
  end

  def overall_rating
    return nil unless has_ratings?

    # Weighted average of ratings
    (
      (attack_rating || 0) * 0.2 +
      (defense_rating || 0) * 0.2 +
      (consistency_rating || 0) * 0.1 +
      (discipline_rating || 0) * 0.2 +
      (skills_rating || 0) * 0.1 +
      (work_rate_rating || 0) * 0.2
    ).round(2)
  end

end
