---
id: task-9
title: Checkout Flow
status: Done
assignee: []
created_date: '2025-07-10'
updated_date: '2025-07-12'
completed_date: '2025-07-12'
labels: []
dependencies: []
priority: high
---

## Description

As a user, I want to subscribe to a monthly, quarterly, or annual susbcription. When I click on the corresponding subscription option, I am able to enter my payment information to Stripe, confirm the payment, and am redirected to the Presentations page after successful payment with 1 credit in my account.

Scenario 1: Subscribe from the Home Page (Complete)
GIVEN I am on the home page
AND I scroll down to the Subscription section
WHEN I click on a subscription card
THEN I am able to enter my payment information in the Stripe Integration
AND I am redirected to the Presentations page with an active subscription

Scenario 2: Subscribe from the Account Page (Complete)
GIVEN I am on my Account -> Subscription Page
WHEN I click on a subscription card
THEN I am able to enter my payment information in the Stripe Integration
AND I am redirected to the Presentations page with an active subscription

## Implementation Notes

Completed on 2025-07-12:
- Added Stripe checkout functionality to home page subscription cards
- When logged in, users see a form that posts to subscriptions_checkout_path with price_id
- When not logged in, users are redirected to auth page first
- Implementation matches the Account page checkout flow pattern
- Both scenarios now functional and tested
