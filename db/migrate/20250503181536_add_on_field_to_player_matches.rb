class AddOnFieldToPlayerMatches < ActiveRecord::Migration[7.1]
  def change
    add_column :player_matches, :on_field, :boolean, default: false, null: false
  end
end
