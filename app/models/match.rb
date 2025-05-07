class Match < ApplicationRecord
  has_many :player_matches, dependent: :destroy
  has_many :players, through: :player_matches

  # Add team associations
  belongs_to :home_team, class_name: 'Team', optional: true
  belongs_to :away_team, class_name: 'Team', optional: true

  accepts_nested_attributes_for :player_matches, allow_destroy: true

  # Add virtual attribute
  attr_accessor :location_type, :opponent_id, :current_team_id

  # Validations
  validates :season, presence: true
  validates :competition, presence: true
  #validates :date, presence: true
  validates :home_team_id, presence: true
  validates :away_team_id, presence: true
  validates :location_type, presence: true, inclusion: { in: %w[home away] }, on: :create
  validates :opponent_id, presence: true, on: :create

  # Make result optional but validate format when present
  validates :result, format: {
    with: /\A\d+\s*-\s*\d+\z/,
    message: "must be in format 'number - number' (e.g., '23 - 22')"
  }, allow_blank: true

  scope :for_team, ->(team_id) {
    where('home_team_id = ? OR away_team_id = ?', team_id, team_id)
  }

  # Add callback to set teams before validation
  before_validation :set_teams

  private

  def set_teams
    return unless location_type.present? && opponent_id.present?

    if location_type == 'home'
      self.home_team_id = current_team_id
      self.away_team_id = opponent_id
    else
      self.away_team_id = current_team_id
      self.home_team_id = opponent_id
    end
  end
end
