class AddIndexesToUsersAndTeams < ActiveRecord::Migration[7.1]
  def change
    add_index :teams, :name
    add_index :teams, :classification
    add_index :users, :role
    add_index :users, :team_id
  end
end
