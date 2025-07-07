class UpdateModeratorToOfficer < ActiveRecord::Migration[8.0]
  def change
    # Update any existing 'moderator' roles to 'officer'
    execute "UPDATE society_memberships SET role = 'officer' WHERE role = 'moderator'"
  end
end
