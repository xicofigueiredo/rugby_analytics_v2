class PlayerMatch < ApplicationRecord
  belongs_to :match
  belongs_to :player
  has_many :actions, dependent: :destroy

  # Add both types of notes
  validates :coach_notes, length: { maximum: 1000 } # adjust max length as needed
  validates :player_notes, length: { maximum: 1000 } # adjust max length as needed

  # Helper methods for action statistics
  def total_actions
    actions.count
  end

  def positive_actions_count
    actions.positive_actions.count
  end

  def negative_actions_count
    actions.negative_actions.count
  end

  def tries_scored
    actions.where(action_type: 'try').count
  end

  def assists
    actions.where(action_type: 'assist').count
  end

  def tackles_made
    actions.where(action_type: 'tackle').count
  end

  def tackles_missed
    actions.where(action_type: 'missed_tackle').count
  end

  def cards_received
    actions.cards.count
  end
end
