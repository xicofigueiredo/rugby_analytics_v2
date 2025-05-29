class Match < ApplicationRecord
  belongs_to :home_team, class_name: 'Team'
  belongs_to :away_team, class_name: 'Team'
  has_many :player_matches, dependent: :destroy
  has_many :players, through: :player_matches

  accepts_nested_attributes_for :player_matches, allow_destroy: true

  # Validations
  validates :season, presence: true
  validates :competition, presence: true
  validates :home_team_id, presence: true
  validates :away_team_id, presence: true
  validate :different_teams

  # Make result optional but validate format when present
  validates :result, format: {
    with: /\A\d+\s*-\s*\d+\z/,
    message: "must be in format 'number - number' (e.g., '23 - 22')"
  }, allow_blank: true

  # Add the coach_notes field to the match model
  validates :coach_notes, length: { maximum: 2000 } # adjust max length as needed

  scope :for_team, ->(team_id) {
    where('home_team_id = ? OR away_team_id = ?', team_id, team_id)
  }

  private

  def different_teams
    if home_team_id.present? && away_team_id.present? && home_team_id == away_team_id
      errors.add(:base, "Home team and away team must be different")
    end
  end
end
