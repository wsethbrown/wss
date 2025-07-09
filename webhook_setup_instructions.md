# 🪝 Stripe Webhook Setup Instructions

## Option 1: Development Testing with ngrok

1. **Install ngrok** (if not already installed):
   ```bash
   brew install ngrok
   ```

2. **Start your Rails server**:
   ```bash
   bin/dev
   ```

3. **In a new terminal, expose your local server**:
   ```bash
   ngrok http 3000
   ```

4. **Copy the HTTPS URL** (something like `https://abc123.ngrok.io`)

5. **Go to Stripe Dashboard** → Developers → Webhooks → Add endpoint

6. **Set the endpoint URL**: `https://abc123.ngrok.io/webhooks/stripe`

7. **Select events to listen for**:
   - `customer.subscription.created`
   - `customer.subscription.updated` 
   - `customer.subscription.deleted`
   - `invoice.payment_succeeded`
   - `invoice.payment_failed`

8. **Copy the webhook signing secret** from Stripe and update your `.env`:
   ```
   STRIPE_WEBHOOK_SECRET=whsec_actual_secret_here
   ```

## Option 2: Using Stripe CLI (Alternative)

1. **Install Stripe CLI**:
   ```bash
   brew install stripe/stripe-cli/stripe
   ```

2. **Login to Stripe**:
   ```bash
   stripe login
   ```

3. **Forward webhooks to your local server**:
   ```bash
   stripe listen --forward-to localhost:3000/webhooks/stripe
   ```

4. **Copy the webhook signing secret** from the CLI output and update `.env`

## Testing the Integration

Once webhook is set up:

1. Start your server: `bin/dev`
2. Visit: `http://localhost:3000/account`
3. Click on "Subscription" tab
4. Click "Choose Monthly" button
5. Complete test checkout with card `4242424242424242`
6. Check Rails logs for webhook events

## What happens when webhooks work:

- User subscription status updates automatically
- Database records are synced with Stripe
- Users see their active subscription in account page
- Subscription management works through Stripe Customer Portal