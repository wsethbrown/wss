namespace :stripe do
  desc "Clean up test subscriptions for a user"
  task :cleanup_subscriptions, [ :email ] => :environment do |t, args|
    unless args[:email]
      puts "Usage: rails stripe:cleanup_subscriptions[user@example.com]"
      exit
    end

    user = User.find_by(email: args[:email])
    unless user
      puts "User not found: #{args[:email]}"
      exit
    end

    puts "Cleaning up subscriptions for #{user.email}..."

    if user.stripe_customer_id.present?
      begin
        # List all subscriptions for this customer
        subscriptions = Stripe::Subscription.list(
          customer: user.stripe_customer_id,
          status: "all",
          limit: 100
        )

        canceled_count = 0
        subscriptions.data.each do |subscription|
          if subscription.status != "canceled"
            puts "Canceling subscription #{subscription.id} (status: #{subscription.status})"
            Stripe::Subscription.cancel(subscription.id)
            canceled_count += 1
          end
        end

        puts "Canceled #{canceled_count} subscriptions"

        # Clear user's subscription data
        user.update!(
          stripe_subscription_id: nil,
          subscription_status: nil,
          subscription_plan: nil,
          subscription_ends_at: nil,
          cancel_at_period_end: false
        )

        puts "Cleared user's subscription data"
        puts "User can now create a new subscription"

      rescue Stripe::StripeError => e
        puts "Error: #{e.message}"
      end
    else
      puts "User has no Stripe customer ID"
    end
  end

  desc "Remove user from test clock"
  task :remove_from_test_clock, [ :email ] => :environment do |t, args|
    unless args[:email]
      puts "Usage: rails stripe:remove_from_test_clock[user@example.com]"
      exit
    end

    user = User.find_by(email: args[:email])
    unless user
      puts "User not found: #{args[:email]}"
      exit
    end

    if user.stripe_customer_id.present?
      puts "To remove customer from test clock:"
      puts "1. Go to Stripe Dashboard > Developers > Test clocks"
      puts "2. Find the test clock with customer #{user.stripe_customer_id}"
      puts "3. Remove the customer from the test clock"
      puts "4. Then run: rails stripe:cleanup_subscriptions[#{user.email}]"
    else
      puts "User has no Stripe customer ID"
    end
  end
end
