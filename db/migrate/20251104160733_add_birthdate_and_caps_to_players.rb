class AddBirthdateAndCapsToPlayers < ActiveRecord::Migration[7.1]
  def change
    add_column :players, :birthdate, :date
    add_column :players, :caps, :integer
  end
end
