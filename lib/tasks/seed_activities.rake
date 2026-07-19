namespace :activities do
  desc "Seed sample activity logs for testing"
  task seed: :environment do
    puts "Creating sample activity logs..."

    # Get a sample user (or create one)
    user = User.find_by(email: "seth@whiskeysharesociety.com") || User.first

    unless user
      puts "No users found. Please create a user first."
      exit
    end

    # Create various activity types
    activities = [
      { type: :login, metadata: { method: "password" } },
      { type: :profile_updated, metadata: { fields: [ "first_name", "last_name" ] } },
      { type: :presentation_viewed, trackable: Presentation.first, metadata: {} },
      { type: :credits_added, metadata: { amount: 5, reason: "manual_grant" } },
      { type: :subscription_created, metadata: { plan: "monthly" } }
    ]

    # Create activities with different timestamps
    activities.each_with_index do |activity, index|
      ActivityLog.create!(
        user: user,
        activity_type: activity[:type],
        trackable: activity[:trackable],
        metadata: activity[:metadata],
        ip_address: "127.0.0.1",
        user_agent: "Mozilla/5.0 (Test Activity)",
        created_at: index.hours.ago
      )
    end

    # Create some activities for other users if they exist
    User.where.not(id: user.id).limit(3).each do |other_user|
      ActivityLog.create!(
        user: other_user,
        activity_type: :login,
        metadata: { method: "oauth", provider: "google" },
        ip_address: "192.168.1.#{rand(1..255)}",
        user_agent: "Mozilla/5.0",
        created_at: rand(1..24).hours.ago
      )
    end

    puts "Created #{ActivityLog.count} activity logs!"
  end

  desc "Clear all activity logs"
  task clear: :environment do
    ActivityLog.destroy_all
    puts "All activity logs cleared."
  end
end
