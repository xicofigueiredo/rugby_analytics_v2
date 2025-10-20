class AddMissingFieldsToPlayerMatches < ActiveRecord::Migration[7.1]
  def change
    add_column :player_matches, :linebreak_assists, :integer
    add_column :player_matches, :other_mistakes, :integer
    add_column :player_matches, :scrum_dominant, :integer
    add_column :player_matches, :mod_game_plus, :integer
    add_column :player_matches, :mod_game_minus, :integer
  end
end
