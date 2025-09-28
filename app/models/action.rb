class Action < ApplicationRecord
  belongs_to :player_match

  # Define valid action types
  VALID_TYPES = %w[
    time_played try conversion missed_conversion penalty_kick_goal missed_penalty_kick_goals
    drop_goal missed_drop_goals try_assist positive_tackle neutral_tackle negative_tackle
    assist_tackle missed_tackle lineout_turnover lineout_won_jump linout_won_no_jump
    introduction_won introduction_lost turnover pen_offside pen_breakdown
    pen_scrum pen_others aerial_duel_won aerial_duel_lost positive_offload negative_offload
    linebreak knock-on positive_carry carries yellow red
  ].freeze

  validates :action_type, presence: true, inclusion: { in: VALID_TYPES }

  # Scopes for easier querying
  scope :positive_actions, -> { where(action_type: %w[ try conversion penalty_kick_goal drop_goal try_assist positive_tackle neutral_tackle assist_tackle lineout_turnover lineout_won_jump linout_won_no_jump introduction_won turnover aerial_duel_won positive_offload linebreak positive_carry carries]) }
  scope :negative_actions, -> { where(action_type: %w[missed_tackle penalty knock-on yellow red negative_tackle negative_offload aerial_duel_lost]) }
  scope :cards, -> { where(action_type: %w[yellow red]) }

end
