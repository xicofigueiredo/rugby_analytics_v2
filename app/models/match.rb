class Match < ApplicationRecord
  has_many :player_matches, dependent: :destroy
  has_many :players, through: :player_matches

  accepts_nested_attributes_for :player_matches, allow_destroy: true

  # Add virtual attribute
  attr_accessor :location_type, :opponent_id


  # Validations
  validates :season, presence: true
  validates :competition, presence: true
  #validates :date, presence: true
  validates :home_team, presence: true
  validates :away_team, presence: true
  validates :location_type, presence: true, inclusion: { in: %w[home away] }, on: :create
  validates :opponent_id, presence: true, on: :create

  # Make result optional but validate format when present
  validates :result, format: {
    with: /\A\d+\s*-\s*\d+\z/,
    message: "must be in format 'number - number' (e.g., '23 - 22')"
  }, allow_blank: true

  scope :for_team, ->(team_name) {
    where('home_team = ? OR away_team = ?', team_name, team_name)
  }
end
