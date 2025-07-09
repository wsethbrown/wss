---
id: task-1
title: Apple Auth Flow
status: Done
assignee: []
created_date: '2025-07-09'
updated_date: '2025-07-09'
labels: []
dependencies: []
priority: high
---

## Description

As a user, I want to login using Apple's "Sign in with Apple" button.

Scenario 1: New User
WHEN I click on Sign in with Apple
AND I successfully login with my Apple credentials
THEN I am logged in with my new account

Scenario 2: Curent User
WHEN I click on Sign in with Apple
AND I successfully login with my Apple credentials
THEN I am logged in with my pre-existing account
