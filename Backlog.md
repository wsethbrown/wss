# Whiskey Share Society Backlog Management

## Overview

WSS uses a file-based kanban board system for managing development tasks and project backlog. This lightweight approach provides version control for tasks and integrates seamlessly with our Git workflow.

## Directory Structure

```
backlog/
├── config.yml          # Backlog configuration
├── tasks/              # Active task files
├── drafts/             # Task drafts and templates
├── archive/            # Completed/archived tasks
│   ├── tasks/         # Archived task files
│   └── drafts/        # Archived drafts
├── decisions/          # Architecture Decision Records (ADRs)
└── docs/              # Backlog-related documentation
```

## Configuration

The `backlog/config.yml` file contains project settings:

```yaml
project_name: "WSS"
default_status: "To Do"
statuses: ["To Do", "In Progress", "Done"]
labels: []
milestones: []
date_format: yyyy-mm-dd
max_column_width: 20
backlog_directory: "backlog"
auto_open_browser: true
default_port: 6420
remote_operations: true
auto_commit: false
```

## Task File Format

Each task is a markdown file with YAML frontmatter:

```markdown
---
id: task-1
title: Implement User Dashboard
status: To Do
assignee: [username]
created_date: '2025-07-09'
labels: [feature, frontend]
dependencies: [task-2, task-3]
---

## Description
Detailed description of the task...

## Acceptance Criteria
- [ ] Dashboard displays user statistics
- [ ] Recent activity feed is functional
- [ ] Responsive design implemented

## Technical Notes
Implementation details...
```

## Workflow

### Creating Tasks

1. **Manual Creation**
   ```bash
   touch "backlog/tasks/task-N - Task-Title.md"
   ```

2. **Using Templates**
   - Create task templates in `backlog/drafts/`
   - Copy and modify for new tasks

### Task Lifecycle

1. **To Do**: New tasks start here
2. **In Progress**: Move when work begins
3. **Done**: Move when completed
4. **Archive**: Move completed tasks to `backlog/archive/tasks/`

### Status Updates

Update the `status` field in the task's frontmatter:
```yaml
status: In Progress
```

## Best Practices

### Task Naming
- Use format: `task-N - Brief-Description.md`
- Keep titles concise but descriptive
- Use hyphens instead of spaces

### Task Content
- Clear description of the problem/feature
- Specific acceptance criteria
- Technical implementation notes
- Links to related issues/PRs

### Labels
Common labels for organization:
- `bug`: Something isn't working
- `feature`: New functionality
- `enhancement`: Improvement to existing features
- `security`: Security-related tasks
- `performance`: Performance improvements
- `documentation`: Documentation updates
- `testing`: Test-related tasks
- `refactor`: Code refactoring
- `frontend`: Frontend-specific tasks
- `backend`: Backend-specific tasks
- `infrastructure`: DevOps/infrastructure tasks

### Dependencies
- List task IDs that must be completed first
- Update when dependencies change
- Review before starting work

## Viewing the Backlog

### Command Line
```bash
# List all tasks
ls backlog/tasks/

# View task details
cat "backlog/tasks/task-1 - Apple-OAuth-Flow.md"

# Search tasks
grep -r "OAuth" backlog/tasks/
```

### Web Interface
If using a backlog visualization tool:
```bash
# Start backlog server (if available)
backlog serve

# Opens at http://localhost:6420
```

## Integration with Development

### Git Workflow
1. Reference task IDs in commit messages
2. Link PRs to tasks
3. Update task status when PRs merge

### Branch Naming
```bash
git checkout -b task-1-apple-oauth-flow
```

### Commit Messages
```
task-1: Implement Apple OAuth callback handler

- Add OAuth state validation
- Handle user creation/update
- Add error handling
```

## Archiving

### When to Archive
- Task has been completed and deployed
- Task is no longer relevant
- Quarterly cleanup of done tasks

### Archive Process
```bash
# Move completed task to archive
mv "backlog/tasks/task-1 - Apple-OAuth-Flow.md" \
   "backlog/archive/tasks/"
```

## Decision Records

Architecture Decision Records (ADRs) go in `backlog/decisions/`:

```markdown
---
id: adr-1
title: Use OAuth for Authentication
date: '2025-07-09'
status: accepted
---

## Context
Why we need to make this decision...

## Decision
What we decided...

## Consequences
What happens as a result...
```

## Reporting

### Task Metrics
- Count by status
- Age of tasks
- Velocity tracking
- Blocker identification

### Generate Reports
```bash
# Count tasks by status
grep -l "status: In Progress" backlog/tasks/*.md | wc -l

# Find old tasks
find backlog/tasks -name "*.md" -mtime +30

# List blocked tasks
grep -l "blocked" backlog/tasks/*.md
```

## Tips for Effective Backlog Management

1. **Regular Grooming**
   - Weekly review of task priorities
   - Update stale task descriptions
   - Archive completed work

2. **Clear Acceptance Criteria**
   - Define "done" explicitly
   - Include testing requirements
   - Specify documentation needs

3. **Realistic Estimation**
   - Break large tasks into smaller ones
   - Consider dependencies
   - Account for testing and review

4. **Communication**
   - Update task status promptly
   - Add notes about blockers
   - Link to relevant discussions

## Common Commands

```bash
# Find all tasks assigned to you
grep -l "assignee: \[your-name\]" backlog/tasks/*.md

# Find high-priority tasks
grep -l "labels: \[.*priority.*\]" backlog/tasks/*.md

# Find tasks modified today
find backlog/tasks -name "*.md" -mtime 0

# Count total active tasks
ls backlog/tasks/*.md | wc -l

# Find tasks with specific label
grep -l "labels: \[.*security.*\]" backlog/tasks/*.md
```

## Future Enhancements

- [ ] Automated kanban board visualization
- [ ] Integration with GitHub Issues
- [ ] Slack notifications for status changes
- [ ] Burndown chart generation
- [ ] Team velocity tracking

## Related Documentation

- @Architecture.md - System architecture overview
- @Database.md - Database schema documentation
- @SecurityChecklist.md - Security implementation checklist