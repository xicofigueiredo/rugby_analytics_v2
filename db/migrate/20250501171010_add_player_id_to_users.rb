class AddPlayerIdToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :player_id, :integer
    add_index :users, :player_id
  end
end
