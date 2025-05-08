class UpdateUserRoles < ActiveRecord::Migration[7.0]
  def up
    # Set a default role for existing users
    User.where(role: nil).update_all(role: 'player')
  end

  def down
    # No need to revert this change
  end
end
