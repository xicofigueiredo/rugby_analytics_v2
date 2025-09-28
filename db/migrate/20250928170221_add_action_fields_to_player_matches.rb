class AddActionFieldsToPlayerMatches < ActiveRecord::Migration[7.1]
  def change
    add_column :player_matches, :time_played, :integer
    add_column :player_matches, :try, :integer
    add_column :player_matches, :conversion, :integer
    add_column :player_matches, :missed_conversion, :integer
    add_column :player_matches, :penalty_kick_goal, :integer
    add_column :player_matches, :missed_penalty_kick_goals, :integer
    add_column :player_matches, :drop_goal, :integer
    add_column :player_matches, :missed_drop_goals, :integer
    add_column :player_matches, :try_assist, :integer
    add_column :player_matches, :positive_tackle, :integer
    add_column :player_matches, :neutral_tackle, :integer
    add_column :player_matches, :negative_tackle, :integer
    add_column :player_matches, :assist_tackle, :integer
    add_column :player_matches, :missed_tackle, :integer
    add_column :player_matches, :lineout_turnover, :integer
    add_column :player_matches, :lineout_won_jump, :integer
    add_column :player_matches, :lineout_won_no_jump, :integer
    add_column :player_matches, :introduction_won, :integer
    add_column :player_matches, :introduction_lost, :integer
    add_column :player_matches, :turnover, :integer
    add_column :player_matches, :pen_offside, :integer
    add_column :player_matches, :pen_breakdown, :integer
    add_column :player_matches, :pen_scrum, :integer
    add_column :player_matches, :pen_others, :integer
    add_column :player_matches, :aerial_duel_won, :integer
    add_column :player_matches, :aerial_duel_lost, :integer
    add_column :player_matches, :positive_offload, :integer
    add_column :player_matches, :negative_offload, :integer
    add_column :player_matches, :linebreak, :integer
    add_column :player_matches, :knock_on, :integer
    add_column :player_matches, :positive_carry, :integer
    add_column :player_matches, :carries, :integer
    add_column :player_matches, :yellow, :integer
    add_column :player_matches, :red, :integer
  end
end
