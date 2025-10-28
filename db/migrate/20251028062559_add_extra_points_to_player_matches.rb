class AddExtraPointsToPlayerMatches < ActiveRecord::Migration[7.1]
  def change
    add_column :player_matches, :extra_points, :integer
  end
end
