class AddPlayerStats < ActiveRecord::Migration[7.1]
  def change
    add_column :players, :nationality, :string
    add_column :players, :cache_counters, :jsonb, default: {}
    add_column :players, :total_points, :integer, default: 0
  end
end
