class AddRcmFieldsToPlayerMatches < ActiveRecord::Migration[7.1]
  def change
    change_table :player_matches, bulk: true do |t|
      t.integer :interception
      t.integer :ruck_clear
      t.integer :ruck_seal
      t.integer :ruck_lost
      t.integer :pen_defense
      t.integer :neutral_carry
      t.integer :negative_carry
      t.integer :good_pass
      t.integer :bad_pass
      t.integer :kick
      t.integer :given_interception
      t.integer :given_turnover
      t.integer :defenders_beaten
      t.integer :atack_penalties
      t.integer :unforced_errors
      t.integer :lineout_won
      t.integer :lineout_lost
      t.integer :kick_pass
      t.integer :drop_on_target
      t.integer :drop_off_target
      t.integer :forced_an_error
      t.integer :misplaced
      t.integer :positive_pick
      t.integer :negative_pick
    end
  end
end
