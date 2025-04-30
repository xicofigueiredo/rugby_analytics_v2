class AddFieldsToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :name, :string
    add_reference :users, :team, foreign_key: true
    add_column :users, :role, :string
    add_column :users, :age, :integer
    add_column :users, :positions, :string, array: true, default: []
    add_column :users, :height, :decimal
    add_column :users, :weight, :decimal
  end
end
