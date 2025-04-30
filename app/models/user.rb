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

  # Validations for player-specific attributes
  with_options if: :player? do |player|
    player.validates :age, presence: true, numericality: { only_integer: true, greater_than: 0 }
    player.validates :positions, presence: true
    player.validate :validate_positions
    player.validates :height, presence: true, numericality: { greater_than: 0 }
    player.validates :weight, presence: true, numericality: { greater_than: 0 }
  end

  def player?
    role == 'player'
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
