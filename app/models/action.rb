class Action < ApplicationRecord
  belongs_to :player_match

  # Define valid action types
  VALID_TYPES = %w[
    try assist tackle missed_tackle lineout_turnover turnover
    penalty offload linebreak knock-on yellow red
  ].freeze

  validates :action_type, presence: true, inclusion: { in: VALID_TYPES }

  # Scopes for easier querying
  scope :positive_actions, -> { where(action_type: %w[try assist tackle offload linebreak]) }
  scope :negative_actions, -> { where(action_type: %w[missed_tackle turnover penalty knock-on yellow red]) }
  scope :lineout_actions, -> { where(action_type: 'lineout_turnover') }
  scope :cards, -> { where(action_type: %w[yellow red]) }

  # Helper methods
  def positive?
    %w[try assist tackle offload linebreak].include?(action_type)
  end

  def negative?
    %w[missed_tackle turnover penalty knock-on yellow red].include?(action_type)
  end

  def card?
    %w[yellow red].include?(action_type)
  end
end
