# Whiskey Share Society Database Schema

## Overview

The WSS database is built on PostgreSQL 16, leveraging Rails' ActiveRecord ORM for database interactions. The schema follows Rails conventions with proper indexing, foreign key constraints, and normalized relationships.

## Core Tables

### Users Table
The central authentication and user profile table.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | bigint | PRIMARY KEY | Auto-incrementing identifier |
| email | string | NOT NULL, UNIQUE | Primary email address |
| encrypted_password | string | NOT NULL | Bcrypt hashed password |
| reset_password_token | string | UNIQUE | Password reset token |
| reset_password_sent_at | datetime | | Token expiration tracking |
| remember_created_at | datetime | | Remember me functionality |
| provider | string | | OAuth provider (google, apple) |
| uid | string | | OAuth provider user ID |
| first_name | string | | User's first name |
| last_name | string | | User's last name |
| bio | text | | User profile biography |
| unconfirmed_email | string | | Pending email change |
| email_change_token | string | | Email change verification |
| email_change_token_expires_at | datetime | | Token expiration |
| otp_secret_key | string | | 2FA secret key |
| otp_enabled | boolean | DEFAULT false | 2FA status |
| backup_codes | text | | 2FA backup codes (encrypted) |
| password_set_manually | boolean | DEFAULT false | OAuth vs manual password |
| stripe_customer_id | string | | Stripe customer reference |
| stripe_subscription_id | string | | Active subscription ID |
| subscription_status | string | | active, canceled, past_due |
| subscription_plan | string | | Plan identifier |
| subscription_ends_at | datetime | | Subscription expiration |

**Indexes:**
- `email` (UNIQUE)
- `reset_password_token` (UNIQUE)

### Societies Table
Whiskey clubs and communities.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | bigint | PRIMARY KEY | Auto-incrementing identifier |
| name | string | NOT NULL | Society name |
| description | text | | Society description |
| location | string | | Geographic location |
| creator_id | bigint | NOT NULL, FK(users) | Society founder |
| is_private | boolean | | Requires approval to join |
| created_at | datetime | NOT NULL | Creation timestamp |
| updated_at | datetime | NOT NULL | Last update timestamp |

**Indexes:**
- `name`
- `location`
- `creator_id`

### Society Memberships Table
Junction table for user-society relationships with roles.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | bigint | PRIMARY KEY | Auto-incrementing identifier |
| user_id | bigint | NOT NULL, FK(users) | Member reference |
| society_id | bigint | NOT NULL, FK(societies) | Society reference |
| role | string | NOT NULL, DEFAULT 'member' | admin, officer, member |
| status | string | NOT NULL, DEFAULT 'active' | active, suspended, banned |
| created_at | datetime | NOT NULL | Membership start |
| updated_at | datetime | NOT NULL | Last update |

**Indexes:**
- `user_id, society_id` (UNIQUE COMPOSITE)
- `role`
- `status`
- `user_id`
- `society_id`

### Society Applications Table
Applications to join private societies.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | bigint | PRIMARY KEY | Auto-incrementing identifier |
| user_id | bigint | NOT NULL, FK(users) | Applicant |
| society_id | bigint | NOT NULL, FK(societies) | Target society |
| message | text | | Application message |
| status | string | | pending, approved, rejected |
| created_at | datetime | NOT NULL | Application date |
| updated_at | datetime | NOT NULL | Last update |

**Indexes:**
- `user_id`
- `society_id`

### Events Table
Society events and gatherings.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | bigint | PRIMARY KEY | Auto-incrementing identifier |
| title | string | NOT NULL | Event name |
| description | text | | Event details |
| location | string | | Event venue |
| start_time | datetime | NOT NULL | Event start |
| end_time | datetime | | Event end |
| society_id | bigint | NOT NULL, FK(societies) | Host society |
| organizer_id | bigint | NOT NULL, FK(users) | Event organizer |
| created_at | datetime | NOT NULL | Creation timestamp |
| updated_at | datetime | NOT NULL | Last update |

**Indexes:**
- `title`
- `location`
- `start_time`
- `society_id`
- `society_id, start_time` (COMPOSITE)
- `organizer_id`

### Event RSVPs Table
Event attendance tracking.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | bigint | PRIMARY KEY | Auto-incrementing identifier |
| user_id | bigint | NOT NULL, FK(users) | Attendee |
| event_id | bigint | NOT NULL, FK(events) | Event reference |
| status | string | NOT NULL, DEFAULT 'pending' | pending, confirmed, declined |
| created_at | datetime | NOT NULL | RSVP date |
| updated_at | datetime | NOT NULL | Last update |

**Indexes:**
- `user_id, event_id` (UNIQUE COMPOSITE)
- `status`
- `user_id`
- `event_id`

### Presentations Table
Educational whiskey content.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | bigint | PRIMARY KEY | Auto-incrementing identifier |
| title | string | NOT NULL | Presentation title |
| description | text | | Content description |
| content | text | | Presentation body |
| author_id | bigint | NOT NULL, FK(users) | Content creator |
| price | decimal(10,2) | DEFAULT 0.0 | Purchase price |
| category | string | | Content category |
| created_at | datetime | NOT NULL | Creation date |
| updated_at | datetime | NOT NULL | Last update |

**Indexes:**
- `title`
- `category`
- `price`
- `author_id`

### Tags Table
Categorization system for users and content.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | bigint | PRIMARY KEY | Auto-incrementing identifier |
| name | string | NOT NULL, UNIQUE | Tag name |
| color | string | NOT NULL, DEFAULT '#3B82F6' | Display color |
| category | string | DEFAULT 'whiskey' | Tag category |
| description | text | | Tag description |
| created_at | datetime | NOT NULL | Creation date |
| updated_at | datetime | NOT NULL | Last update |

**Indexes:**
- `name` (UNIQUE)
- `category`

### User Tags Table
Junction table for user interests and preferences.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | bigint | PRIMARY KEY | Auto-incrementing identifier |
| user_id | bigint | NOT NULL, FK(users) | User reference |
| tag_id | bigint | NOT NULL, FK(tags) | Tag reference |
| created_at | datetime | NOT NULL | Association date |
| updated_at | datetime | NOT NULL | Last update |

**Indexes:**
- `user_id, tag_id` (UNIQUE COMPOSITE)
- `user_id`
- `tag_id`

### Forums Table
Discussion boards for societies.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | bigint | PRIMARY KEY | Auto-incrementing identifier |
| society_id | bigint | NOT NULL, FK(societies) | Parent society |
| name | string | | Forum name |
| description | text | | Forum description |
| created_at | datetime | NOT NULL | Creation date |
| updated_at | datetime | NOT NULL | Last update |

**Indexes:**
- `society_id`

## ActiveStorage Tables

Rails' built-in file attachment system for user avatars and presentation materials.

### active_storage_blobs
Metadata for uploaded files.

### active_storage_attachments
Polymorphic associations linking files to records.

### active_storage_variant_records
Image transformation tracking.

## Database Design Principles

### 1. Normalization
- 3NF compliance for data integrity
- Junction tables for many-to-many relationships
- No duplicate data storage

### 2. Indexing Strategy
- Primary keys on all tables
- Foreign key indexes for joins
- Composite indexes for common queries
- Unique constraints where appropriate

### 3. Data Types
- Appropriate column types for data
- Decimal for financial data (price)
- Text for unlimited length content
- Datetime for temporal data

### 4. Constraints
- NOT NULL on required fields
- Foreign key constraints for referential integrity
- Default values where sensible
- Check constraints via model validations

## Common Queries

### Finding User's Societies
```sql
SELECT s.* FROM societies s
JOIN society_memberships sm ON sm.society_id = s.id
WHERE sm.user_id = ? AND sm.status = 'active';
```

### Upcoming Events for a Society
```sql
SELECT * FROM events
WHERE society_id = ? AND start_time > NOW()
ORDER BY start_time ASC;
```

### User's Available Presentations
```sql
-- Direct purchases
SELECT p.* FROM presentations p
JOIN user_presentations up ON up.presentation_id = p.id
WHERE up.user_id = ? AND up.purchase_type = 'direct';

-- Credit purchases (requires active subscription)
SELECT p.* FROM presentations p
JOIN user_presentations up ON up.presentation_id = p.id
JOIN users u ON u.id = up.user_id
WHERE up.user_id = ? 
  AND up.purchase_type = 'credit'
  AND u.subscription_status = 'active';
```

## Migration Best Practices

### 1. Reversible Migrations
Always include both `up` and `down` methods or use `change` with reversible operations.

### 2. Data Migrations
Separate schema changes from data migrations for safety.

### 3. Index Creation
Add indexes in separate migrations for large tables to avoid locking.

### 4. Column Defaults
Set defaults at database level for consistency.

### 5. Null Constraints
Be careful when adding NOT NULL to existing columns with data.

## Performance Considerations

### 1. Query Optimization
- Use `includes` to prevent N+1 queries
- Leverage database views for complex queries
- Consider materialized views for analytics

### 2. Partitioning Strategy
- Consider partitioning events by date
- Archive old society_applications
- Partition user activity logs by month

### 3. Connection Pooling
- Configure appropriate pool size
- Monitor connection usage
- Use read replicas for reports

## Backup and Recovery

### 1. Backup Strategy
- Daily full backups
- Continuous WAL archiving
- Point-in-time recovery capability

### 2. Testing Restores
- Regular restore testing
- Document recovery procedures
- Monitor backup success

### 3. Data Retention
- Define retention policies
- Archive old data appropriately
- Comply with privacy regulations