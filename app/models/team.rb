class Team < ApplicationRecord
  has_many :users, dependent: :restrict_with_error
  has_many :players
  has_many :home_matches, class_name: 'Match', foreign_key: 'home_team_id'
  has_many :away_matches, class_name: 'Match', foreign_key: 'away_team_id'

  validates :name, presence: true,
                  uniqueness: { case_sensitive: false },
                  length: { minimum: 2, maximum: 50 }
  validates :level, presence: true
  validates :classification, numericality: { only_integer: true }
  # validates :abbreviation, presence: true, length: { minimum: 2, maximum: 5 }
  # validates :main_color, presence: true
  # validates :secondary_color, presence: true

  def matches
    Match.where('home_team_id = ? OR away_team_id = ?', id, id)
  end
end
