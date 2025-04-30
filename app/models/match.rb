class Match < ApplicationRecord
  validates :season, presence: true
  validates :competition, presence: true
  #validates :date, presence: true
  validates :home_team, presence: true
  validates :away_team, presence: true
  validates :result, presence: true
end
