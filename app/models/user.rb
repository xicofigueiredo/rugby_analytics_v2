class User < ApplicationRecord
  belongs_to :team, optional: true

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  validates :name, presence: true
  validates :role, presence: true, inclusion: { in: %w[player coach fan admin] }

  # Define valid positions
  VALID_POSITIONS = [
    'Loosehead Prop', 'Hooker', 'Tighthead Prop',
    'Lock', 'Flanker', 'Number 8',
    'Scrum-half', 'Fly-half', 'Wing',
    'Centre', 'Full-back'
  ].freeze

  # Scopes
  scope :players, -> { where(role: 'player') }
  scope :ordered, -> { order(name: :asc) }
  scope :with_team, -> { includes(:team) }
  scope :by_position, ->(position) {
    where("? = ANY (positions)", position) if position.present?
  }
  scope :by_team, ->(team_id) { where(team_id: team_id) if team_id.present? }

  # Validations for player-specific attributes
  with_options if: :player? do |player|
    player.validates :age, presence: true,
                         numericality: { only_integer: true,
                                       greater_than: 15,
                                       less_than: 50 }
    player.validates :positions, presence: true,
                               length: { minimum: 1 }
    player.validate :validate_positions
    player.validates :height, presence: true,
                            numericality: { greater_than: 150,
                                          less_than: 220 }
    player.validates :weight, presence: true,
                            numericality: { greater_than: 50,
                                          less_than: 150 }
  end

  # Methods
  def player?
    role == 'player'
  end

  def position_list
    positions&.join(', ') || 'No positions assigned'
  end

  def physical_stats
    return unless player?
    "#{height}cm, #{weight}kg"
  end

  def age_and_positions
    return unless player?
    "#{age} years - #{position_list}"
  end

  private

  def validate_positions
    return if positions.blank?

    invalid_positions = positions - VALID_POSITIONS
    if invalid_positions.any?
      errors.add(:positions, "contains invalid positions: #{invalid_positions.join(', ')}")
    end
  end
end
