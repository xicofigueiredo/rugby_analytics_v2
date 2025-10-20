class AddOverallRatingToPlayerMatches < ActiveRecord::Migration[7.1]
  def change
    add_column :player_matches, :overall_rating, :decimal, precision: 4, scale: 2
  end
end
