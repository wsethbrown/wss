---
id: task-28
title: Update Admin Presentation Creation Form
status: Done
assignee: []
created_date: '2025-07-15'
labels: []
dependencies: []
completed_date: '2025-07-15'
---

## Description

Add 'What You\'ll learn', 'Presentation Overview', 'Slides Preview' (utilizing our preview slide images as a hero headre for this section), using actual dollar amounts in the Recommended Whiskey section

## Implementation

### Database Changes:
- Added `what_youll_learn` text field to presentations table
- Added `slides_preview` text field to presentations table
- Added `whiskey_recommendations_json` jsonb field for structured recommendations

### Admin Form Updates:
- Updated Presentation Overview label and help text
- Added "What You'll Learn" text area with line-by-line entry
- Added "Slides Preview" text area with pipe-delimited format
- Updated whiskey recommendations to include:
  - Price field (actual dollar amounts)
  - Style field
  - Tasting Notes field

### Presentation Show Page Updates:
- Added dynamic "What You'll Learn" section with colored cards
- Added "Slides Preview" section that parses slide data
- Updated whiskey recommendations to show:
  - Actual prices (e.g., $45)
  - Style information
  - Tasting notes when available

### Styling Fixes:
- Matched the hardcoded presentation styling
- Fixed whiskey recommendation cards
- Improved spacing and layout consistency
