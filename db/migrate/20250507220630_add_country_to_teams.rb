class AddCountryToTeams < ActiveRecord::Migration[7.0]
  def change
    add_column :teams, :country, :string, null: false, default: 'Portugal'
  end
end
