class CreateTeams < ActiveRecord::Migration[7.1]
  def change
    create_table :teams do |t|
      t.string :name
      t.string :level
      t.integer :classification

      t.timestamps
    end
  end
end
