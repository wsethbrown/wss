---
id: task-23
title: Click Subscription Card to Begin Checkout Flow
status: Done
assignee: []
created_date: '2025-07-14'
updated_date: '2025-07-14'
labels: []
dependencies: []
---

## Description

As a User, I want to click anywhere on the Subscription card to choose my subscription and begin the checkout.

SCENARIO 1: Account -> Subscription Tab
GIVEN I am not a current Subscriber
WHEN I click anywhere on any plan's card
THEN I am taken through the checkout flow for that subscription

SCENARIO 2: Adjust Plans
GIVEN I am a current Subscriber
WHEN I click "Adjust plan"
AND I have the option to choose any plan but my current plan
WHEN I click anywhere on a Subscription card
THEN I am taken through the checkout flow for that subscription
