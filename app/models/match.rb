class Match < ApplicationRecord
  # Add virtual attribute
  attr_accessor :location_type, :opponent_id

  # Validations
  validates :season, presence: true
  validates :competition, presence: true
  #validates :date, presence: true
  validates :home_team, presence: true
  validates :away_team, presence: true
  validates :result, presence: true
  validates :location_type, presence: true, inclusion: { in: %w[home away] }, on: :create
  validates :opponent_id, presence: true, on: :create

  scope :for_team, ->(team_name) {
    where('home_team = ? OR away_team = ?', team_name, team_name)
  }
end
