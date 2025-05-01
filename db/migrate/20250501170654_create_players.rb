class CreatePlayers < ActiveRecord::Migration[7.1]
  def change
    create_table :players do |t|
      t.integer :age
      t.integer :height
      t.decimal :weight
      t.string :positions, array: true, default: []
      t.references :team, null: false, foreign_key: true

      t.timestamps
    end
  end
end
