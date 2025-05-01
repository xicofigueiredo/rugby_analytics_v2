class AddPlayersCountToTeams < ActiveRecord::Migration[7.1]
  def change
    add_column :teams, :players_count, :integer, default: 0, null: false
  end
end
