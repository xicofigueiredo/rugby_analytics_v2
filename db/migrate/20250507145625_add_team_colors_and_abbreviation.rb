class AddTeamColorsAndAbbreviation < ActiveRecord::Migration[7.1]
  def change
    add_column :teams, :abbreviation, :string
    add_column :teams, :main_color, :string
    add_column :teams, :secondary_color, :string
  end
end
