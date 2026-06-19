-- ElderSmartHelper Database Schema (Simplified)
-- Version: 2.0.0
-- Updated: 2026-05-07

CREATE DATABASE IF NOT EXISTS elder_smart_helper
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

USE elder_smart_helper;

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

-- Security events table (securityService depends on this)
CREATE TABLE IF NOT EXISTS security_events (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    event_type ENUM('fraud_detected', 'suspicious_link', 'payment_attempt', 'risk_warning') NOT NULL,
    severity ENUM('low', 'medium', 'high', 'critical') NOT NULL DEFAULT 'medium',
    description TEXT,
    metadata JSON,
    is_resolved BOOLEAN DEFAULT FALSE,
    resolved_at TIMESTAMP NULL,
    resolved_by INT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id),
    INDEX idx_event_type (event_type),
    INDEX idx_severity (severity),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insert sample users (password: 123456, bcrypt hash)
INSERT INTO users (phone, password, name, user_type) VALUES
('13800000001', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', '张爷爷', 'elderly'),
('13800000002', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', '小张', 'family'),
('13800000000', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', '管理员', 'admin');

-- Insert sample family relationship
INSERT INTO family_relationships (elderly_user_id, family_user_id, relationship) VALUES
(1, 2, 'child');

-- Insert sample tutorials
INSERT INTO tutorials (title, description, category, difficulty_level, steps) VALUES
('如何拨打电话', '学习使用手机拨打电话的基本操作', 'basic', 'beginner',
'[{"step":1,"title":"找到电话图标","description":"在主屏幕上找到绿色的电话图标，通常在底部Dock栏"},{"step":2,"title":"点击电话图标","description":"用手指轻轻点击电话图标，进入拨号界面"},{"step":3,"title":"输入电话号码","description":"在数字键盘上依次输入要拨打的电话号码"},{"step":4,"title":"点击拨号按钮","description":"点击绿色的拨号按钮，等待对方接听"}]');

INSERT INTO tutorials (title, description, category, difficulty_level, steps) VALUES
('如何使用微信聊天', '学习使用微信发送文字和语音消息', 'communication', 'beginner',
'[{"step":1,"title":"打开微信","description":"找到绿色的微信图标，点击打开"},{"step":2,"title":"选择联系人","description":"在聊天列表中点击要聊天的好友"},{"step":3,"title":"发送文字","description":"点击底部输入框，输入文字后点击发送"},{"step":4,"title":"发送语音","description":"长按底部麦克风图标，说完话后松开即可发送语音"}]');

INSERT INTO tutorials (title, description, category, difficulty_level, steps) VALUES
('如何连接WiFi', '学习连接家里的无线网络', 'utility', 'beginner',
'[{"step":1,"title":"打开设置","description":"找到齿轮形状的设置图标，点击打开"},{"step":2,"title":"进入WiFi设置","description":"点击无线网络或WLAN选项"},{"step":3,"title":"选择网络","description":"在列表中找到你家的WiFi名称，点击它"},{"step":4,"title":"输入密码","description":"输入WiFi密码，点击连接"}]');

INSERT INTO tutorials (title, description, category, difficulty_level, steps) VALUES
('如何视频通话', '学习使用微信进行视频通话', 'communication', 'intermediate',
'[{"step":1,"title":"打开微信","description":"找到微信图标，点击打开"},{"step":2,"title":"选择联系人","description":"找到要视频通话的好友，点击进入聊天"},{"step":3,"title":"发起视频通话","description":"点击右下角加号，选择视频通话"},{"step":4,"title":"等待接听","description":"等待对方接听，接通后即可看到对方画面"}]');
INSERT INTO tutorials (title, description, category, difficulty_level, steps) VALUES
('如何发送短信', '学习使用手机发送和接收短信', 'basic', 'beginner',
'[{"step":1,"title":"打开信息应用","description":"找到绿色的信息图标，点击打开短信应用"},{"step":2,"title":"新建短信","description":"点击右下角的加号或新建按钮"},{"step":3,"title":"输入号码","description":"在收件人栏输入对方的手机号码，或从通讯录中选择联系人"},{"step":4,"title":"输入内容并发送","description":"在输入框中输入短信内容，点击发送按钮"}]');

INSERT INTO tutorials (title, description, category, difficulty_level, steps) VALUES
('如何设置闹钟', '学习使用手机闹钟功能，每天按时起床', 'utility', 'beginner',
'[{"step":1,"title":"打开时钟应用","description":"找到时钟图标，通常是一个圆形的钟表样式"},{"step":2,"title":"进入闹钟页面","description":"点击底部的闹钟选项卡"},{"step":3,"title":"添加闹钟","description":"点击加号按钮，设置你想要的闹钟时间"},{"step":4,"title":"保存闹钟","description":"设置好时间和重复日期后，点击保存或确定按钮"}]');

INSERT INTO tutorials (title, description, category, difficulty_level, steps) VALUES
('如何拍照和查看相册', '学习使用相机拍照和在相册中查看照片', 'utility', 'beginner',
'[{"step":1,"title":"打开相机","description":"找到相机图标，点击打开相机应用"},{"step":2,"title":"对准拍摄对象","description":"将手机对准你想拍摄的人或景物"},{"step":3,"title":"按下快门","description":"点击屏幕下方中间的圆形按钮拍照"},{"step":4,"title":"查看照片","description":"点击左下角的小缩略图，即可进入相册查看刚拍的照片"}]');

INSERT INTO tutorials (title, description, category, difficulty_level, steps) VALUES
('如何使用微信支付', '学习使用微信进行扫码付款和收付款', 'payment', 'intermediate',
'[{"step":1,"title":"打开微信","description":"找到微信图标，点击打开"},{"step":2,"title":"进入收付款","description":"点击右上角加号，选择收付款"},{"step":3,"title":"出示付款码","description":"将生成的付款码展示给商家扫码"},{"step":4,"title":"确认支付","description":"商家扫码后，在手机上确认支付金额即可完成付款"}]');

INSERT INTO tutorials (title, description, category, difficulty_level, steps) VALUES
('如何发送微信朋友圈', '学习在微信朋友圈分享生活动态', 'entertainment', 'intermediate',
'[{"step":1,"title":"打开微信","description":"找到微信图标，点击打开"},{"step":2,"title":"进入朋友圈","description":"点击底部发现，然后点击朋友圈"},{"step":3,"title":"发布动态","description":"点击右上角相机图标，选择拍照或从相册选择图片"},{"step":4,"title":"编辑并发送","description":"输入你想说的话，点击右上角发表按钮"}]');

INSERT INTO tutorials (title, description, category, difficulty_level, steps) VALUES
('如何使用手机看新闻', '学习使用今日头条等应用浏览新闻资讯', 'entertainment', 'beginner',
'[{"step":1,"title":"打开新闻应用","description":"找到今日头条或新闻应用图标，点击打开"},{"step":2,"title":"浏览首页推荐","description":"首页会显示推荐的新闻，上下滑动即可浏览"},{"step":3,"title":"点击阅读","description":"看到感兴趣的标题，点击即可进入阅读详细内容"},{"step":4,"title":"返回首页","description":"阅读完毕后，点击左上角返回箭头回到首页"}]');

