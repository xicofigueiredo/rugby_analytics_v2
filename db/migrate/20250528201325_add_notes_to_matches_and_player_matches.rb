class AddNotesToMatchesAndPlayerMatches < ActiveRecord::Migration[7.1]
  def change
    add_column :matches, :coach_notes, :text

    add_column :player_matches, :coach_notes, :text
    add_column :player_matches, :player_notes, :text
  end
end
