# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## ⭐ Active overhaul — read OVERHAUL_PLAN.md first

A full refresh/refactor is in progress on branch `overhaul/full-refresh`. **@OVERHAUL_PLAN.md** is the
source of truth for what's done and what's next. Key invariants established there (do not regress):

- **Auth:** Only three paths — Devise password, magic link (`Auth::MagicLinkService`), and OmniAuth
  (Google always; Apple only when `APPLE_*` env vars are set). There are NO hand-rolled OAuth
  callbacks; never add one, and never disable OAuth/JWT signature verification.
- **Admin:** Roles are the `users.admin_role` enum (none/limited/full). `User#admin?` is true for any
  admin tier; `User#can_delete?` is true only for full (limited admins keep every admin power except
  hard-deleting records). `admin_role` is the source of truth; the old `is_admin` boolean is vestigial.
  Do not reintroduce email-domain admin checks.
- **Credits:** `credit_transactions` is the ledger and single source of truth. `users.credits` is a
  cache recomputed from the ledger; NEVER write it directly. All changes go through
  `CreditTransaction.record!` / `use_credit` / `grant_monthly_credit` / `expire_all_credits`.
- **Stripe webhooks:** Idempotent via the `StripeEvent` claim table — process each event once.
- **Secrets:** No `.pem`/`.key`/`.env`/`*.log` in git (see `.gitignore`); use env vars / credentials.
  The previously committed Apple signing key is compromised and must be rotated.
- **Design:** One warm `whiskey-*` Tailwind palette is the brand accent (not indigo/amber).

## Development Commands

### Starting the Application
- `bin/dev` - Starts the development server with Foreman (Rails server + Tailwind CSS watcher)
- `rails server` - Start Rails server only
- `rails db:create db:migrate db:seed` - Set up database

### Database Operations
- `rails db:migrate` - Run pending migrations
- `rails db:rollback` - Rollback last migration
- `rails db:seed` - Seed database with sample data
- `rails db:reset` - Drop, create, migrate, and seed database

### Asset Management
- `rails tailwindcss:watch` - Watch Tailwind CSS changes
- `rails assets:precompile` - Precompile assets for production

### Code Quality
- `rubocop` - Run Ruby linter (configured with omakase style)
- `brakeman` - Run security vulnerability scanner

### Testing
- `rails test` - Run all tests
- `rails test:models` - Run model tests only
- `rails test:controllers` - Run controller tests only
- `rails test:integration` - Run integration tests only
- `rails test:system` - Run system tests only
- `rails test test/models/society_test.rb` - Run specific test file
- `rails test test/models/society_test.rb:10` - Run specific test method (line 10)

### Email Testing (Magic Links)
- `bin/magic-links` - Show all magic link URLs for testing
- `bin/latest-email` - View the full content of the most recent email
- `bin/clear-emails` - Delete all test emails

### Development Philosophy
- **Test-Driven Development**: We use TDD at WSS. Always write tests first, then implement features to make them pass

### Docker
- `docker-compose up --build` - Build and run application in Docker
- `docker build -t whiskey-share-society .` - Build Docker image

## Architecture Overview

### Core Domain Models
- **User**: Authentication via Devise with OAuth (Google, Apple), role-based permissions
- **Society**: Whiskey clubs with public/private visibility, admin/officer/member roles
- **Event**: Society events with RSVP system
- **Presentation**: Professional whiskey presentations with purchase system
- **SocietyMembership**: Junction table managing user roles within societies
- **SocietyApplication**: Handles applications to join private societies

### Authentication & Authorization
- **Devise**: User authentication with OAuth providers
- **Pundit**: Authorization policies for resource access
- **Role System**: Admin, Officer, Member roles with hierarchical permissions

### Frontend Architecture
- **Hotwire**: Modern Rails frontend with Turbo and Stimulus
- **Tailwind CSS**: Utility-first styling with glassmorphism effects
- **Stimulus Controllers**: Located in `app/javascript/controllers/`

### Key Business Logic
- Users can create societies and automatically become admins
- Private societies require applications for membership
- Role-based permissions control society management
- Event RSVP system integrated with society memberships
- Professional presentations available for purchase
- Once subscribed, a user receives 1 credit per month on the 1st of the month (and immediately after subscribing)
  - How can this be resolved with mid-month activations?
- Presentations can be purchased directly for a cost or exchanged for a credit
- Presentations bought directly with money are accessible forever in a user's account
- Presentations purchased with credits are always accessible as long as they have an active subscription
  - A user can have a mix of "a la carte" and "credit-purchased" presentations available in their account


### File Structure
- `app/models/` - ActiveRecord models with associations and business logic
- `app/controllers/` - Rails controllers with Pundit authorization
- `app/policies/` - Pundit policy classes for authorization
- `app/views/` - ERB templates with Hotwire integration
- `config/routes.rb` - Conditional routing based on authentication state
- `db/migrate/` - Database schema migrations

### Notable Patterns
- Conditional root routes based on authentication state
- OAuth callback handling for social login
- Role-based scopes and helper methods on models
- Hierarchical permission system for society management

## Security Guidelines

**CRITICAL**: Security is paramount for Whiskey Share Society. All development and assistance must adhere to these strict security principles:

### Credential Protection
- **NEVER expose credentials** in any form, format, or context
- **NEVER display, log, or output** API keys, secrets, tokens, or passwords
- **NEVER commit credentials** to version control (use .env files with .gitignore)
- **NEVER share credentials** in screenshots, code snippets, or discussions
- **ALWAYS use environment variables** for sensitive configuration
- **ALWAYS verify .env files are gitignored** before committing any code

### OAuth & Authentication Security
- **Validate redirect URIs** carefully to prevent OAuth hijacking
- **Use secure session management** with proper expiration
- **Implement CSRF protection** for all OAuth flows
- **Sanitize OAuth callback data** before processing
- **Log authentication failures** for security monitoring
- **Use HTTPS only** in production for all OAuth callbacks

### Data Protection
- **Encrypt sensitive user data** (PII, payment info, preferences)
- **Implement proper access controls** via Pundit policies
- **Sanitize all user inputs** to prevent XSS and injection attacks
- **Use parameterized queries** to prevent SQL injection
- **Validate file uploads** strictly (type, size, content)
- **Implement rate limiting** to prevent abuse

### Authorization & Permissions
- **Verify user permissions** on every protected action
- **Use least privilege principle** for all role assignments
- **Audit permission changes** in society memberships
- **Implement proper session timeout** and logout
- **Validate society membership** before showing private content
- **Check ownership** before allowing edits/deletions

### Development Security
- **Run security scanners** regularly (brakeman, bundler-audit)
- **Keep dependencies updated** and monitor for vulnerabilities
- **Use secure development environment** with proper isolation
- **Review all code changes** for potential security issues
- **Test authentication flows** thoroughly in development
- **Validate production deployment** security configuration

### Privacy & Compliance
- **Respect user privacy** and data minimization principles
- **Implement proper data retention** policies
- **Allow users to delete** their accounts and data
- **Secure user communications** within societies
- **Protect whiskey preferences** and purchase history
- **Handle payment data** according to PCI DSS standards

### Incident Response
- **Monitor for security events** and anomalies
- **Have incident response plan** for data breaches
- **Log security-relevant events** for audit trails
- **Implement proper error handling** without information disclosure
- **Prepare breach notification** procedures
- **Maintain security contact** information

**Remember**: Whiskey Share Society handles sensitive user data, financial transactions, and private community information. Every security measure protects our users' trust and privacy.

## 📚 CRITICAL DOCUMENTATION PATTERN
**ALWAYS ADD IMPORTANT DOCS HERE!** When you create or discover:
- Architecture diagrams → Add reference path here
- Database schemas → Add reference path here
- Problem solutions → Add reference path here
- Setup guides → Add reference path here

This prevents context loss! Update this file IMMEDIATELY when creating important docs.

### Key Documentation References
- **@Architecture.md** - System architecture overview, technology stack, design patterns, and scalability planning
- **@Database.md** - Complete database schema documentation, relationships, indexes, and common queries
- **@SecurityChecklist.md** - Comprehensive security checklist, best practices, and incident response procedures
- **@Backlog.md** - Task management system using file-based kanban boards and workflow documentation
- **@admin_panel_todo.md** - Admin panel development plan, requirements, and progress tracking

### Admin Panel Development
**IMPORTANT**: When working on admin panel features:
1. **Always update admin_panel_todo.md** with progress
2. Mark completed items with [x]
3. Add new requirements as discovered
4. Update the "Last Updated" date
5. Move completed phases to a "Completed" section
6. Document any architectural decisions or changes

This ensures continuity across sessions and maintains a clear development roadmap.

### Logging (STANDING RULE — applies to every change, not just debugging)

**Logging is part of the definition of done.** New code ships with the logging it
needs to be diagnosed in production from logs alone. Do not add it later "if there's
a problem" — by then the evidence is gone. Ask of every new path: *if this fails at
2am for one user, could I tell what happened from the logs?* If not, add a line.

Log at these points, with the IDs needed to trace the actor and the record:
- **Significant state changes** (`info`): a record created/destroyed that matters
  (invitations, memberships, hosts, decks assigned), money or credits moving, emails
  and notifications enqueued (say how many and who was skipped and why), background
  jobs starting/finishing/no-oping.
- **Rejected or refused actions** (`warn`): failed auth, invalid/expired tokens,
  permission denials, validation refusals that a user will complain about.
- **Every rescue** (`error`): never swallow an exception silently. Include the class,
  message, and the ids in play. A bare `rescue => e` with no log is a bug.
- **Silent no-ops** (`info`): guard clauses that return early (record gone, feature
  flag off, mute enabled) — the absence of an effect must be explainable.

Rules:
- Include identifiers (`user 42`, `event 17`, `society 3`), never bare "failed".
- **NEVER log secrets**: tokens, API keys, passwords, session, full params, raw
  magic-link/invite/RSVP tokens. Log that a token was invalid, never its value.
  (See Security Guidelines above — this is non-negotiable.)
- Match existing phrasing so logs read consistently; grep a neighbouring
  controller/service/job before inventing a new format.

### Debugging
- Use extensive logging to debug problems; leave the useful lines in place afterward.

### Stripe Webhook Configuration
For the credit system and subscriptions to work properly, you need to configure Stripe webhooks:

1. **In Stripe Dashboard**:
   - Go to Developers → Webhooks
   - Add endpoint: `https://your-domain.com/webhooks/stripe`
   - Select events: 
     - `customer.subscription.created`
     - `customer.subscription.updated`
     - `customer.subscription.deleted`
     - `invoice.payment_succeeded`
     - `checkout.session.completed`
   - Copy the webhook signing secret to your `.env` file as `STRIPE_WEBHOOK_SECRET`

2. **For Local Development**:
   - Install Stripe CLI: `brew install stripe/stripe-cli/stripe`
   - Login: `stripe login`
   - Forward webhooks: `stripe listen --forward-to localhost:3000/webhooks/stripe`
   - Use the webhook secret provided by the CLI in your `.env`

3. **Testing Credits**:
   - New subscriptions automatically grant 1 credit
   - Monthly renewals grant 1 credit
   - Credits expire when subscription ends

### Git Workflow
- Whenever a new feature is marked as complete by the User, make a new commit and push it up

/file:.claude-on-rails/context.md