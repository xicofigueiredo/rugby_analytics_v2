class Player < ApplicationRecord
  belongs_to :team, counter_cache: true
  has_one :user

  # Validations
  validates :age, presence: true, numericality: { only_integer: true, greater_than: 13, less_than: 50 }
  validates :height, presence: true, numericality: { only_integer: true, greater_than: 150, less_than: 220 }
  validates :weight, presence: true, numericality: { greater_than: 40, less_than: 170 }
  validates :positions, presence: true
  # validates :nationality, presence: true
  # validates :total_points, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :validate_positions

  VALID_POSITIONS = [
    'Loosehead Prop', 'Hooker', 'Tighthead Prop',
    'Lock', 'Flanker', 'Number 8',
    'Scrum-half', 'Fly-half', 'Wing',
    'Centre', 'Full-back'
  ].freeze

  private

  def validate_positions
    return if positions.blank?
    invalid_positions = positions - VALID_POSITIONS
    if invalid_positions.any?
      errors.add(:positions, "contains invalid positions: #{invalid_positions.join(', ')}")
    end
  end
end
