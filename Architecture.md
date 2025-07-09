# Whiskey Share Society Architecture

## System Overview

Whiskey Share Society is a Ruby on Rails 8 application built with modern web standards, focusing on community management, event organization, and educational content delivery for whiskey enthusiasts.

## Technology Stack

### Backend
- **Ruby 3.3.0** with Rails 8.0.0 (latest stable)
- **PostgreSQL 16** for primary data storage
- **Redis** for caching and ActionCable websockets
- **ActiveJob** with Sidekiq for background processing
- **ActiveStorage** for file uploads (user avatars, presentation materials)

### Frontend
- **Hotwire (Turbo + Stimulus)** for reactive interfaces without heavy JavaScript
- **Tailwind CSS** with glassmorphism design patterns
- **Importmap** for modern JavaScript without bundling complexity
- **Stimulus Controllers** for interactive components

### Authentication & Security
- **Devise** with multi-provider OAuth support:
  - Google OAuth 2.0
  - Apple Sign In
  - Magic link authentication via email
- **Pundit** for fine-grained authorization policies
- **bcrypt** for secure password hashing
- **SSL/TLS** enforced in production

### Infrastructure
- **Docker** containerization for development and deployment
- **Puma** web server with multi-threaded request handling
- **Nginx** reverse proxy in production
- **Foreman** for process management in development

## Application Architecture

### MVC Structure
```
app/
├── controllers/       # Request handling and routing logic
│   ├── concerns/     # Shared controller modules
│   └── users/        # Namespace for user-related controllers
├── models/           # Business logic and data models
│   └── concerns/     # Shared model modules
├── views/            # ERB templates with Hotwire integration
│   ├── layouts/      # Application layouts
│   └── shared/       # Reusable partials
├── policies/         # Pundit authorization policies
├── mailers/          # Email delivery classes
├── javascript/       # Stimulus controllers and utilities
│   └── controllers/  # Stimulus JS controllers
└── assets/           # Static assets and Tailwind config
```

### Key Design Patterns

#### 1. Role-Based Access Control (RBAC)
- Hierarchical roles: Admin > Officer > Member
- Society-scoped permissions
- User global roles vs Society membership roles

#### 2. Service Objects (Future Implementation)
```ruby
app/services/
├── authentication/
│   ├── magic_link_service.rb
│   └── oauth_handler_service.rb
├── society/
│   ├── membership_manager.rb
│   └── application_processor.rb
└── presentation/
    ├── credit_manager.rb
    └── purchase_handler.rb
```

#### 3. Concerns for Shared Behavior
- `Authenticatable` - OAuth and magic link authentication
- `Authorizable` - Role-based permission checks
- `Subscribable` - Subscription and credit management

#### 4. Background Job Architecture
- Email delivery via ActiveJob
- Monthly credit allocation jobs
- Subscription status checks
- Event reminder notifications

### Data Flow

#### Authentication Flow
1. User initiates login (OAuth/Magic Link)
2. AuthController handles provider callback
3. User model creates or updates record
4. Session established with remember token
5. Redirect to authenticated dashboard

#### Society Membership Flow
1. User discovers society (public listing or invite)
2. Applies for membership (if private)
3. Admin/Officer reviews application
4. Membership created with appropriate role
5. Access granted to society resources

#### Presentation Purchase Flow
1. User browses available presentations
2. Selects purchase method (credit or direct)
3. Payment processed (Stripe for direct)
4. Access granted and recorded
5. Content delivered via secure URLs

### Caching Strategy
- Fragment caching for society listings
- Russian doll caching for nested resources
- Redis-backed session storage
- CDN for static assets and presentations

### API Design (Future)
```
/api/v1/
├── societies/        # Public society data
├── events/          # Upcoming events
├── presentations/   # Available content
└── users/          # Profile management
```

### Performance Considerations
- N+1 query prevention with includes/joins
- Database indexing on foreign keys and search fields
- Lazy loading for images and heavy content
- Turbo frames for partial page updates
- Background job processing for heavy operations

### Scalability Planning
- Horizontal scaling with load balancer
- Read replicas for database
- Redis clustering for cache
- CDN distribution for global access
- Microservice extraction points identified

## Security Architecture

See @SecurityChecklist.md for detailed security implementation guidelines.

### Key Security Features
- OAuth state validation
- CSRF protection on all forms
- XSS prevention with sanitization
- SQL injection protection via ActiveRecord
- Rate limiting on authentication endpoints
- Encrypted credentials in Rails 8

## Development Workflow

### Local Development
1. `bin/setup` - Initial project setup
2. `bin/dev` - Start development servers
3. `bin/test` - Run test suite
4. `bin/console` - Rails console access

### Testing Strategy
- Model specs for business logic
- Controller specs for request handling
- System specs for user workflows
- Policy specs for authorization
- Mailer specs for email delivery

### Deployment Pipeline
1. Code push to repository
2. CI/CD runs test suite
3. Security scanning (Brakeman)
4. Docker image build
5. Rolling deployment
6. Health check verification

## Monitoring & Observability

### Application Monitoring
- Request performance tracking
- Error tracking and alerting
- User behavior analytics
- Business metric dashboards

### Infrastructure Monitoring
- Server resource utilization
- Database query performance
- Cache hit rates
- Background job queues

### Logging Strategy
- Structured JSON logging
- Log aggregation service
- Security event tracking
- Audit trail maintenance