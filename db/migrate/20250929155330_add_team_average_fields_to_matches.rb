class AddTeamAverageFieldsToMatches < ActiveRecord::Migration[7.1]
  def change
    add_column :matches, :avg_time_played, :float
    add_column :matches, :avg_positive_tackle, :float
    add_column :matches, :avg_neutral_tackle, :float
    add_column :matches, :avg_negative_tackle, :float
    add_column :matches, :avg_assist_tackle, :float
    add_column :matches, :avg_missed_tackle, :float
    add_column :matches, :avg_turnover, :float
    add_column :matches, :avg_pen_offside, :float
    add_column :matches, :avg_pen_breakdown, :float
    add_column :matches, :avg_pen_scrum, :float
    add_column :matches, :avg_pen_others, :float
    add_column :matches, :avg_aerial_duel_won, :float
    add_column :matches, :avg_aerial_duel_lost, :float
    add_column :matches, :avg_positive_offload, :float
    add_column :matches, :avg_negative_offload, :float
    add_column :matches, :avg_linebreak, :float
    add_column :matches, :avg_knock_on, :float
    add_column :matches, :avg_positive_carry, :float
    add_column :matches, :avg_carries, :float
  end
end
