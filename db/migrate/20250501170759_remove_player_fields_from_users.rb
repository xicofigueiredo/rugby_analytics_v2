class RemovePlayerFieldsFromUsers < ActiveRecord::Migration[7.1]
  def change
    remove_column :users, :age, :integer
    remove_column :users, :height, :integer
    remove_column :users, :weight, :decimal
    remove_column :users, :positions, :string
  end
end
