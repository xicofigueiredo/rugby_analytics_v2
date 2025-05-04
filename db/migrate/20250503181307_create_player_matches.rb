class CreatePlayerMatches < ActiveRecord::Migration[7.1]
  def change
    create_table :player_matches do |t|
      t.references :player, null: false, foreign_key: true
      t.references :match, null: false, foreign_key: true
      t.boolean :started, default: false, null: false
      t.integer :minutes_played, default: 0, null: false

      t.timestamps
    end
  end
end
