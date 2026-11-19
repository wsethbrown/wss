# Redesign and backend programme — how the work is run

The owner asked for the whole site (including admin) to be redesigned and the backend
review findings fixed, with **Opus as the orchestrator**, **Fable 5.2 as the advisor**, and
each task delegated to an appropriately sized model. This file is the operating manual.
The work itself is in `TASKS.md`; the design rules are in `DESIGN_SYSTEM.md`; the review
is in `ARCHITECTURE_REVIEW.md`.

## Roles

| Role | Who | Does |
|---|---|---|
| Orchestrator | The Opus session running this programme | Sequences waves, briefs workers, integrates, runs the gates, commits and pushes, keeps `TASKS.md` status current. Does not do task work itself except integration fixes. |
| Workers | Sub-agents spawned by the orchestrator at the model named on each task (`haiku`, `sonnet`, `opus`) | One task each, inside the files the task owns. |
| Advisor | The Fable 5.2 session that wrote the plan (`session_012RnJvL6fdGk9zB2BHzZdmL`) | Answers design and architecture questions, reviews each wave's screenshots, rules on ambiguity. Reached with the claude-code-remote `send_message` tool. |
| Owner | Seth | Approves new copy, merges PRs, decides anything marked **[owner]**. |

### When to ask the advisor
Ask before proceeding when: a task's acceptance criteria conflict with what the code
allows; a design question is not answered by `DESIGN_SYSTEM.md`; a worker proposes new
user-facing copy; a backend fix needs a migration that rewrites data; a review finding
looks wrong. Send one message per question with the task id, the options and your
recommendation, then carry on with work that does not depend on the answer. At the end of
every wave, send the advisor the wave's screenshot paths and a three-line summary.

## Sizing rule
- `haiku`: mechanical, fully specified, low blast radius (palette swaps, renames, docs).
- `sonnet`: a well-specified feature or page redesign following established patterns.
- `opus`: work that sets a pattern others copy, touches money/auth/authorisation, or has
  delicate interactive behaviour.
Escalate a task one size up if a worker fails its gate twice; do not retry at the same size
a third time.

## Briefing a worker
Give each worker: the task block from `TASKS.md` verbatim, the "Definition of done"
section below, the paths of `DESIGN_SYSTEM.md` and the relevant `.claude/skills/wss-*`
skill, the environment section below, and the names of files it must not touch. Tell it to
hand back in the format at the end of this file. Workers cannot spawn sub-agents.

## Waves and parallelism
Tasks in one wave own disjoint files and may run in parallel **in the same checkout**. Do
not use worktrees: there is one dev database and one dev server. Rules for parallel work:
- A worker edits only the files its task owns. A needed change elsewhere is reported, not
  made.
- Workers run only their own targeted test files. **Only the orchestrator runs the full
  suite**, between waves, never while workers are running (one test database).
- Only the orchestrator runs `git add/commit/push` and `bin/rails tailwindcss:build`
  after `application.css` changes (workers ask for a rebuild in their hand-back, or run it
  if they are the only task in the wave that owns that file).
- One commit per task, message `"<task id>: <summary>"`, with the attribution lines the
  session provides. Push after each wave.

## Gates (orchestrator, after every wave)
1. `bin/rails test` green by its printed summary (see `.claude/skills/wss-testing`; one
   re-run is allowed for the documented parallel flake, never a third).
2. `bundle exec rubocop` clean on changed Ruby files; `bundle exec brakeman -q` shows no
   new warnings (the Rails end-of-life warning is known and tracked in wsethbrown/wss#36).
3. Every changed page screenshotted at 1440px and 390px, signed out and signed in as
   relevant, with `document.documentElement.scrollWidth` equal to the viewport width.
4. `grep` shows no new `bg-char` page mastheads, no `uppercase tracking-` labels, no emoji
   used as icons, and no `yellow`/`amber`/`indigo`/`purple`/`blue-` utilities in changed
   views (admin semantic status colours excepted where the task says so).
5. The copy rule: any new user-facing words are listed in the wave summary for the owner.

## Definition of done (every task)
- Acceptance criteria in the task block all hold, each one checked, not assumed.
- The task's test plan was run and its output is in the hand-back.
- No behaviour change outside the task's stated goal: same routes, params, authorisation,
  Turbo/Stimulus hooks (`data-*` attributes, element ids used by streams and tests).
- Logging per `CLAUDE.md` for any new Ruby path; no secrets or tokens logged.
- No fabricated content. No new copy without listing it.
- Verified in a browser, not only by tests.

## Environment (fresh cloud container)
```bash
cd /home/user/wss && bundle install
pg_ctlcluster 16 main start
su postgres -c "psql -c \"CREATE ROLE wss SUPERUSER LOGIN PASSWORD 'password'\""
export DATABASE_USERNAME=wss DATABASE_PASSWORD=password
bin/rails db:create db:schema:load db:seed
RAILS_ENV=test bin/rails db:create db:schema:load
bin/rails runner 'User.find_by(email: "admin@whiskeysharesociety.com").update_columns(admin_role: "full")'
bin/rails runner script/dev/seed_showcase_deck.rb   # one deck with real slides
bin/rails tailwindcss:build
nohup bin/rails server -p 3000 -b 127.0.0.1 > /tmp/wss-server.log 2>&1 &
```
The container has Ruby 3.3.6, not the pinned 3.4.x; the app and suite run on it. Docker is
not available, so ignore the `docker compose` commands in the skills. Sign in for
screenshots at `/auth`: fill `#magic-link-email`, click `#password-toggle`, set
`#signin-email`'s value, fill `#signin-password`, submit. Users: `test@example.com`
(member with credits) and `admin@whiskeysharesociety.com` (admin), password `password`.
Chromium and Playwright are pre-installed (`require('playwright')`); do not install them.

## Branches and PRs
Work on the branch this session was started on. Do not push to `main` or to
`claude/sleepy-thompson-wfneis`. Open one **draft** PR against
`claude/sleepy-thompson-wfneis` when the first wave lands and keep pushing to it. Never
merge, approve, deploy, or touch production. wsethbrown/wss#36 (Rails 8.1 upgrade) is
separate; do not duplicate it.

## Worker hand-back format
```
TASK <id> — <done | blocked>
Files changed: ...
Acceptance criteria: <each criterion> — pass/fail + how checked
Tests run: <command> → <summary line>
Screenshots: <paths>
New copy for owner approval: <list, or "none">
Needed outside my files: <list, or "none">
Notes / risks: ...
```
