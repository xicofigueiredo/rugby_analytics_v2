class AddRatingFieldsToPlayerMatches < ActiveRecord::Migration[7.1]
  def change
    add_column :player_matches, :attack_rating, :float
    add_column :player_matches, :defense_rating, :float
    add_column :player_matches, :consistency_rating, :float
    add_column :player_matches, :discipline_rating, :float
    add_column :player_matches, :skills_rating, :float
    add_column :player_matches, :work_rate_rating, :float
  end
end
