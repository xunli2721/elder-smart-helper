# Database Schema and Migrations

## Overview
This directory contains database schemas, migration scripts, and seed data for the ElderSmartHelper application.

## Database Design

### Core Tables

#### 1. Users
Stores user information including elderly users and their family members.
```sql
CREATE TABLE users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    uuid VARCHAR(36) UNIQUE NOT NULL,
    phone VARCHAR(20) UNIQUE NOT NULL,
    email VARCHAR(255),
    name VARCHAR(100) NOT NULL,
    user_type ENUM('elderly', 'family', 'admin') NOT NULL,
    avatar_url VARCHAR(500),
    language_preference VARCHAR(10) DEFAULT 'zh-CN',
    font_size ENUM('small', 'medium', 'large', 'xlarge') DEFAULT 'large',
    voice_speed INT DEFAULT 1, -- 1: slow, 2: normal, 3: fast
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_phone (phone),
    INDEX idx_user_type (user_type)
);
```

#### 2. Family Relationships
Links elderly users with their family members for remote assistance.
```sql
CREATE TABLE family_relationships (
    id INT PRIMARY KEY AUTO_INCREMENT,
    elderly_user_id INT NOT NULL,
    family_user_id INT NOT NULL,
    relationship ENUM('child', 'spouse', 'relative', 'friend', 'caregiver') NOT NULL,
    permission_level ENUM('view', 'assist', 'full') DEFAULT 'assist',
    is_primary_contact BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (elderly_user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (family_user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY unique_relationship (elderly_user_id, family_user_id),
    INDEX idx_elderly (elderly_user_id),
    INDEX idx_family (family_user_id)
);
```

#### 3. Devices
Tracks registered devices for each user.
```sql
CREATE TABLE devices (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    device_uuid VARCHAR(100) UNIQUE NOT NULL,
    device_type ENUM('android', 'ios') NOT NULL,
    device_model VARCHAR(100),
    os_version VARCHAR(50),
    app_version VARCHAR(20),
    fcm_token VARCHAR(255), -- For push notifications
    last_active TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user (user_id),
    INDEX idx_device_uuid (device_uuid)
);
```

#### 4. Tutorials
Stores step-by-step tutorials for smartphone operations.
```sql
CREATE TABLE tutorials (
    id INT PRIMARY KEY AUTO_INCREMENT,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    category ENUM('basic', 'communication', 'payment', 'entertainment', 'utility') NOT NULL,
    difficulty_level ENUM('beginner', 'intermediate', 'advanced') DEFAULT 'beginner',
    estimated_time_minutes INT DEFAULT 5,
    image_url VARCHAR(500),
    video_url VARCHAR(500),
    steps JSON NOT NULL, -- Array of step objects
    views_count INT DEFAULT 0,
    completion_count INT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_category (category),
    INDEX idx_difficulty (difficulty_level)
);
```

#### 5. Remote Assistance Sessions
Logs remote assistance requests and sessions.
```sql
CREATE TABLE remote_sessions (
    id INT PRIMARY KEY AUTO_INCREMENT,
    session_uuid VARCHAR(36) UNIQUE NOT NULL,
    elderly_user_id INT NOT NULL,
    assistant_user_id INT NOT NULL,
    status ENUM('requested', 'active', 'completed', 'cancelled', 'failed') NOT NULL,
    request_description TEXT,
    started_at TIMESTAMP NULL,
    ended_at TIMESTAMP NULL,
    duration_seconds INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (elderly_user_id) REFERENCES users(id),
    FOREIGN KEY (assistant_user_id) REFERENCES users(id),
    INDEX idx_elderly_user (elderly_user_id),
    INDEX idx_assistant (assistant_user_id),
    INDEX idx_status (status)
);
```

#### 6. Security Events
Logs security-related events and alerts.
```sql
CREATE TABLE security_events (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    event_type ENUM('fraud_detected', 'payment_attempt', 'suspicious_link', 'unusual_behavior', 'risk_warning') NOT NULL,
    severity ENUM('low', 'medium', 'high', 'critical') NOT NULL,
    description TEXT,
    metadata JSON,
    is_resolved BOOLEAN DEFAULT FALSE,
    resolved_at TIMESTAMP NULL,
    resolved_by INT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id),
    INDEX idx_user_event (user_id, event_type),
    INDEX idx_severity (severity),
    INDEX idx_created (created_at)
);
```

## Migration Scripts
- `migrations/` - Contains versioned migration scripts
- Use a migration tool like `db-migrate` or manual SQL scripts

## Seed Data
- `seeds/` - Initial data for development and testing
- Includes sample tutorials, default settings, and test users

## Usage

### Initial Setup
1. Create the database:
   ```sql
   CREATE DATABASE elder_smart_helper CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   ```

2. Run the initial schema:
   ```bash
   mysql -u username -p elder_smart_helper < schema.sql
   ```

3. Apply migrations:
   ```bash
   npm run migrate:up
   ```

### Development
- Always create migration scripts for schema changes
- Never modify existing migration files
- Test migrations on a copy of the database first

### Production
- Backup database before applying migrations
- Schedule migrations during low-traffic periods
- Monitor performance after schema changes

## Backup and Recovery
See [BACKUP.md](BACKUP.md) for backup procedures and disaster recovery plans.