-- ElderSmartHelper Database Schema
-- 创建数据库
CREATE DATABASE IF NOT EXISTS elder_smart_helper
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE elder_smart_helper;

-- 1. 用户表
CREATE TABLE IF NOT EXISTS users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    phone VARCHAR(20) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    name VARCHAR(100) NOT NULL,
    user_type ENUM('elderly', 'family', 'admin') NOT NULL DEFAULT 'elderly',
    avatar_url VARCHAR(500) DEFAULT NULL,
    font_size ENUM('small', 'medium', 'large', 'xlarge') NOT NULL DEFAULT 'large',
    language_preference VARCHAR(10) DEFAULT 'zh-CN',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_phone (phone),
    INDEX idx_user_type (user_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. 家庭关系表
CREATE TABLE IF NOT EXISTS family_relationships (
    id INT PRIMARY KEY AUTO_INCREMENT,
    elderly_user_id INT NOT NULL,
    family_user_id INT NOT NULL,
    relationship ENUM('child', 'spouse', 'relative', 'friend', 'caregiver') NOT NULL DEFAULT 'child',
    permission_level ENUM('view', 'assist', 'full') DEFAULT 'assist',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (elderly_user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (family_user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY unique_relationship (elderly_user_id, family_user_id),
    INDEX idx_elderly (elderly_user_id),
    INDEX idx_family (family_user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3. 教程表
CREATE TABLE IF NOT EXISTS tutorials (
    id INT PRIMARY KEY AUTO_INCREMENT,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    category ENUM('basic', 'communication', 'payment', 'entertainment', 'utility') NOT NULL DEFAULT 'basic',
    difficulty_level ENUM('beginner', 'intermediate', 'advanced') DEFAULT 'beginner',
    image_url VARCHAR(500) DEFAULT NULL,
    video_url VARCHAR(500) DEFAULT NULL,
    steps JSON NOT NULL,
    views_count INT DEFAULT 0,
    completion_count INT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_category (category),
    INDEX idx_difficulty (difficulty_level),
    INDEX idx_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4. 远程协助会话表
CREATE TABLE IF NOT EXISTS remote_sessions (
    id INT PRIMARY KEY AUTO_INCREMENT,
    session_uuid VARCHAR(36) NOT NULL,
    elderly_user_id INT NOT NULL,
    assistant_user_id INT NOT NULL,
    status ENUM('requested', 'active', 'completed', 'cancelled', 'failed') NOT NULL DEFAULT 'requested',
    request_description TEXT,
    started_at TIMESTAMP NULL,
    ended_at TIMESTAMP NULL,
    duration_seconds INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (elderly_user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (assistant_user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_elderly_user (elderly_user_id),
    INDEX idx_assistant (assistant_user_id),
    INDEX idx_status (status),
    INDEX idx_session_uuid (session_uuid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
