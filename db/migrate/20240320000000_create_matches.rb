class CreateMatches < ActiveRecord::Migration[7.0]
  def change
    create_table :matches do |t|
      t.string :season
      t.string :competition
      t.string :description
      t.date :date
      t.string :home_team
      t.string :away_team
      t.string :result

      t.timestamps
    end
  end
end
