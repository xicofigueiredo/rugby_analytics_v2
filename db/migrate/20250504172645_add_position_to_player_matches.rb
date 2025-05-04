class AddPositionToPlayerMatches < ActiveRecord::Migration[7.1]
  def change
    add_column :player_matches, :position, :integer
  end
end
