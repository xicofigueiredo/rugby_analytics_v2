class AddRatingFieldsToTeamstats < ActiveRecord::Migration[7.1]
  def change
    add_column :teamstats, :attack_rating, :float
    add_column :teamstats, :defense_rating, :float
    add_column :teamstats, :consistency_rating, :float
    add_column :teamstats, :discipline_rating, :float
    add_column :teamstats, :skills_rating, :float
    add_column :teamstats, :work_rate_rating, :float
  end
end
