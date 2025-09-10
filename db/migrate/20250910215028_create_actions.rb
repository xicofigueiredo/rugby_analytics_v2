class CreateActions < ActiveRecord::Migration[7.1]
  def change
    create_table :actions do |t|
      t.references :player_match, null: false, foreign_key: true
      t.string :action_type, null: false

      t.timestamps
    end

    # Add an index for better query performance
    add_index :actions, :action_type
    add_index :actions, [:player_match_id, :action_type]
  end
end
