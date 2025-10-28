class Teamstat < ApplicationRecord
  belongs_to :match
  belongs_to :team

  validates :lineouts_won, :lineouts_lost, :lineouts_stolen, :lineouts_not_stolen,
            :scrums_won, :scrums_lost, :scrums_stolen, :scrums_not_stolen,
            presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Calculate totals
  def total_lineouts
    lineouts_won + lineouts_lost
  end

  def total_scrums
    scrums_won + scrums_lost
  end

  def lineout_success_rate
    return 0 if total_lineouts == 0
    (lineouts_won.to_f / total_lineouts * 100).round(1)
  end

  def scrum_success_rate
    return 0 if total_scrums == 0
    (scrums_won.to_f / total_scrums * 100).round(1)
  end

  # Lineout steal rate (lineouts stolen from opponent)
  def lineout_steal_rate
    total_opponent_lineouts = lineouts_stolen + lineouts_not_stolen
    return 0 if total_opponent_lineouts == 0
    (lineouts_stolen.to_f / total_opponent_lineouts * 100).round(1)
  end

  # Scrum steal rate (scrums stolen from opponent)
  def scrum_steal_rate
    total_opponent_scrums = scrums_stolen + scrums_not_stolen
    return 0 if total_opponent_scrums == 0
    (scrums_stolen.to_f / total_opponent_scrums * 100).round(1)
  end

  # Rating calculation methods
  def calculate_ratings!
    TeamRatingService.new(self).calculate_all_ratings!
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
    ).round(1)
  end
end
