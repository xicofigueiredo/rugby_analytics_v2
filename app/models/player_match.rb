class PlayerMatch < ApplicationRecord
  belongs_to :match
  belongs_to :player

  # Add both types of notes
  validates :coach_notes, length: { maximum: 1000 } # adjust max length as needed
  validates :player_notes, length: { maximum: 1000 } # adjust max length as needed
end
