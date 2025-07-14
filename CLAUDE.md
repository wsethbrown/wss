# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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

### Debugging
- You should use extensive logging to debug problems.

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