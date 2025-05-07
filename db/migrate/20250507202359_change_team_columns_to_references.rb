class ChangeTeamColumnsToReferences < ActiveRecord::Migration[7.0]
  def up
    # First, add the new columns
    add_column :matches, :home_team_id, :bigint
    add_column :matches, :away_team_id, :bigint

    # Add foreign key constraints
    add_foreign_key :matches, :teams, column: :home_team_id
    add_foreign_key :matches, :teams, column: :away_team_id

    # Migrate existing data
    Match.find_each do |match|
      if match.home_team.present?
        home_team = Team.find_by(name: match.home_team)
        match.update_column(:home_team_id, home_team.id) if home_team
      end

      if match.away_team.present?
        away_team = Team.find_by(name: match.away_team)
        match.update_column(:away_team_id, away_team.id) if away_team
      end
    end

    # Remove old columns
    remove_column :matches, :home_team
    remove_column :matches, :away_team
  end

  def down
    # Add back the string columns
    add_column :matches, :home_team, :string
    add_column :matches, :away_team, :string

    # Migrate data back
    Match.find_each do |match|
      if match.home_team_id.present?
        home_team = Team.find_by(id: match.home_team_id)
        match.update_column(:home_team, home_team.name) if home_team
      end

      if match.away_team_id.present?
        away_team = Team.find_by(id: match.away_team_id)
        match.update_column(:away_team, away_team.name) if away_team
      end
    end

    # Remove the new columns
    remove_column :matches, :home_team_id
    remove_column :matches, :away_team_id
  end
end
