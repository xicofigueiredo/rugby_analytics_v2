class CreateTeamstats < ActiveRecord::Migration[7.1]
  def change
    create_table :teamstats do |t|
      t.references :match, null: false, foreign_key: true
      t.references :team, null: false, foreign_key: true
      t.integer :lineouts_won, default: 0, null: false
      t.integer :lineouts_lost, default: 0, null: false
      t.integer :lineouts_stolen, default: 0, null: false
      t.integer :lineouts_not_stolen, default: 0, null: false
      t.integer :scrums_won, default: 0, null: false
      t.integer :scrums_lost, default: 0, null: false
      t.integer :scrums_stolen, default: 0, null: false
      t.integer :scrums_not_stolen, default: 0, null: false

      t.timestamps
    end
    add_index :teamstats, [:match_id, :team_id], unique: true
  end
end
