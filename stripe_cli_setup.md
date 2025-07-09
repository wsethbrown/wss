# 🚀 Stripe CLI Setup (Recommended)

## Installation & Setup

1. **Install Stripe CLI**:
   ```bash
   brew install stripe/stripe-cli/stripe
   ```

2. **Login to your Stripe account**:
   ```bash
   stripe login
   ```
   (This will open a browser to authenticate)

3. **Start your Rails server**:
   ```bash
   bin/dev
   ```

4. **In a new terminal, start webhook forwarding**:
   ```bash
   stripe listen --forward-to localhost:3000/webhooks/stripe
   ```

5. **Copy the webhook signing secret** from the CLI output (looks like `whsec_...`)

6. **Update your .env file** with the secret:
   ```
   STRIPE_WEBHOOK_SECRET=whsec_actual_secret_from_cli_output
   ```

7. **Restart your Rails server** to pick up the new environment variable

## Testing the Full Flow

1. **Test subscription creation**:
   - Go to `http://localhost:3000/account`
   - Click "Subscription" tab
   - Click "Choose Monthly"
   - Use test card: `4242424242424242`
   - Complete checkout

2. **Watch the webhook events** in your Stripe CLI terminal

3. **Test event simulation** (optional):
   ```bash
   stripe trigger customer.subscription.created
   ```

## What You'll See

- Real-time webhook events in CLI
- Database updates in Rails logs
- User subscription status changes
- Automatic customer creation in Stripe

## Advantages Over ngrok

- ✅ Consistent webhook endpoint
- ✅ Real-time event visibility  
- ✅ Built-in test event triggers
- ✅ No tunnel management
- ✅ Automatic secret generation