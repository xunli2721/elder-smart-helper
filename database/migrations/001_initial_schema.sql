-- Migration: 001_initial_schema
-- Description: Create initial database schema
-- Version: 1.0.0
-- Date: 2026-06-08

-- Create database
CREATE DATABASE IF NOT EXISTS elder_smart_helper
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

USE elder_smart_helper;

-- Migration tracking table
CREATE TABLE IF NOT EXISTS migrations (
    id INT PRIMARY KEY AUTO_INCREMENT,
    version VARCHAR(20) NOT NULL UNIQUE,
    description VARCHAR(255) NOT NULL,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    phone VARCHAR(20) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    name VARCHAR(100) NOT NULL,
    user_type ENUM('elderly', 'family', 'admin') NOT NULL,
    font_size ENUM('small', 'medium', 'large', 'xlarge') DEFAULT 'large',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_phone (phone),
    INDEX idx_user_type (user_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Family relationships table
CREATE TABLE IF NOT EXISTS family_relationships (
    id INT PRIMARY KEY AUTO_INCREMENT,
    elderly_user_id INT NOT NULL,
    family_user_id INT NOT NULL,
    relationship ENUM('child', 'spouse', 'relative', 'friend', 'caregiver') NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (elderly_user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (family_user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY unique_relationship (elderly_user_id, family_user_id),
    INDEX idx_elderly (elderly_user_id),
    INDEX idx_family (family_user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tutorials table
CREATE TABLE IF NOT EXISTS tutorials (
    id INT PRIMARY KEY AUTO_INCREMENT,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    category ENUM('basic', 'communication', 'payment', 'entertainment', 'utility') NOT NULL,
    difficulty_level ENUM('beginner', 'intermediate', 'advanced') DEFAULT 'beginner',
    image_url VARCHAR(500),
    steps JSON NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_category (category)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Remote assistance sessions table
CREATE TABLE IF NOT EXISTS remote_sessions (
    id INT PRIMARY KEY AUTO_INCREMENT,
    elderly_user_id INT NOT NULL,
    assistant_user_id INT NOT NULL,
    status ENUM('requested', 'active', 'completed', 'cancelled') NOT NULL DEFAULT 'requested',
    request_description TEXT,
    started_at TIMESTAMP NULL,
    ended_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (elderly_user_id) REFERENCES users(id),
    FOREIGN KEY (assistant_user_id) REFERENCES users(id),
    INDEX idx_elderly_user (elderly_user_id),
    INDEX idx_assistant (assistant_user_id),
    INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Devices table (for FCM push notifications)
CREATE TABLE IF NOT EXISTS devices (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    device_uuid VARCHAR(100) NOT NULL,
    device_type ENUM('android', 'ios', 'web') NOT NULL,
    device_model VARCHAR(100),
    os_version VARCHAR(50),
    app_version VARCHAR(20),
    fcm_token VARCHAR(500),
    last_active TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY unique_device (user_id, device_uuid),
    INDEX idx_user_id (user_id),
    INDEX idx_fcm_token (fcm_token)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Chat messages table (persistent message storage)
CREATE TABLE IF NOT EXISTS chat_messages (
    id INT PRIMARY KEY AUTO_INCREMENT,
    session_id INT NOT NULL,
    sender_id INT NOT NULL,
    message_type ENUM('text', 'screenshot', 'annotation') NOT NULL DEFAULT 'text',
    content TEXT,
    image_data LONGTEXT,
    metadata JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (session_id) REFERENCES remote_sessions(id) ON DELETE CASCADE,
    FOREIGN KEY (sender_id) REFERENCES users(id),
    INDEX idx_session_id (session_id),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Security events table
CREATE TABLE IF NOT EXISTS security_events (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Record migration
INSERT INTO migrations (version, description) VALUES ('001', 'Initial schema');
