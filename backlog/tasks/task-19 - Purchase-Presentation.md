---
id: task-19
title: Purchase Presentation
status: Done
assignee: []
created_date: '2025-07-12'
completed_date: '2025-07-12'
labels: []
dependencies: []
priority: high
---

## Description

As a User, I want to be able to buy a Purchase, either with real money or with a subscription credit.

GIVEN I am in the detailed view of a Presentation
AND I am an active Subscriber

Scenario 1: Purchase "A La Carte"
WHEN I click on "Purchase Now"
THEN I am taken to the Stripe Checkout
AND I have the option to use a Subscription Credit or purchase "A La Carte"
WHEN I choose "A La Carte"
THEN my card is charged for the correct amount and my Subscription Credit amount does not decrease

Scnario 2: Purchase with Subscription Credit
WHEN I click on "Purchase Now"
THEN I am taken to the Stripe Checkout
AND I have the option to use a Subscription Credit or purchase "A La Carte"
WHEN I choose "Subscription Credit"
THEN my card is not charged and my Subscription Credit amount decreases by 1

GIVEN I am in the detailed view of a Presentation
AND I am not an active Subscriber
OR I have no Subscription Credits Remaining

Scenario 3: Purchase "A La Carte"
WHEN I click on "Purchase Now"
THEN I am taken to the Stripe Checkout. I am not given a choice of "a la carte" or "subscription credit"
THEN my card is charged for the correct amount

## Implementation Notes

Completed on 2025-07-12:

### Database Schema
- Added `credits` column to users table (already existed)
- Enhanced `user_presentations` table with purchase details (purchase_type, price, stripe_payment_intent_id)
- Created `credit_transactions` table for audit trail

### Models & Associations
- Created `CreditTransaction` model with transaction tracking
- Updated `User`, `Presentation`, and `UserPresentation` models
- Added helper methods for purchase validation and access control

### Purchase Flow Implementation
- Created dedicated purchase page at `/presentations/:id/purchases/new`
- Shows credit option for subscribers with credits
- Shows direct purchase option for all users
- Handles both purchase methods through `Presentations::PurchasesController`

### Stripe Integration
- Credit purchases handled entirely in-app (no Stripe interaction)
- Direct purchases create Stripe checkout session
- Webhook handling for payment confirmation
- Automatic credit granting on subscription activation/renewal

### UI Updates
- Added purchase buttons to presentation show page
- Replaced modal with dedicated purchase flow page
- Added credit balance display in navbar for active subscribers
- Shows appropriate messaging based on purchase status

### Key Features
- A la carte purchases provide permanent access
- Credit purchases require active subscription
- Credits expire when subscription ends
- Full transaction history maintained
- Proper access control based on purchase type
