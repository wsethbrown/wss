---
id: task-26
title: Presentations Card Styling
status: Done
assignee: []
created_date: '2025-07-15'
labels: []
dependencies: []
completed_date: '2025-07-15'
---

## Description

The length, difficulty, rating, view details, and favorite buttons should all be aligned at the bottom of each card.

## Implementation

- Updated presentation cards to use flexbox layout with `flex flex-col h-full`
- Used `flex-grow` on the description to fill available space
- Added `mt-auto` to the bottom section to push it to the bottom
- Converted hardcoded presentation data to use actual database fields
- Updated modal JavaScript to handle database objects properly
- Added dynamic tasting notes and recommendations display in modal
- Fixed image handling to use ActiveStorage URLs with fallbacks
