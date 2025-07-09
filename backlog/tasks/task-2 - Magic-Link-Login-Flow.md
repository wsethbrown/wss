---
id: task-2
title: Magic Link Login Flow
status: To Do
assignee: []
created_date: '2025-07-09'
labels: []
dependencies: []
priority: high
---

## Description

As a user, I want to login using the Magic Link button.

Scenario 1: New User
WHEN I click on Sign in with Magic Link
AND I enter a valid email
THEN I see a success toast telling me a Magic Link has been sent to my email
THEN I check my email
AND I click the Magic Link in my email
THEN the Link takes me to the Whiskey Share Society webpage with a successful login notification
AND I am logged in with a new account, tied to my email

Scenario 2: Existing User
WHEN I click on Sign in with Magic Link
AND I enter a valid email
THEN I see a success toast telling me a Magic Link has been sent to my email
THEN I check my email
AND I click the Magic Link in my email
THEN the Link takes me to the Whiskey Share Society webpage with a successful login notification
AND I am logged in with my pre-existing account
