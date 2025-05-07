class RenameNationalityToCountry < ActiveRecord::Migration[7.1]
  def change
    rename_column :players, :nationality, :country
  end
end
