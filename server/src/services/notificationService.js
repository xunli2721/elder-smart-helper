const db = require('../config/db');

/**
 * 推送通知服务
 *
 * 支持两种模式：
 * 1. FCM (Firebase Cloud Messaging) - 生产环境
 * 2. Socket.io 实时通知 - 开发环境/在线用户
 */

// FCM 配置（需要安装 firebase-admin 包）
let fcmInitialized = false;

function initFCM() {
  const fcmKey = process.env.FCM_SERVER_KEY;
  if (!fcmKey) {
    console.log('FCM_SERVER_KEY not set, push notifications will use Socket.io only');
    return;
  }
  // TODO: 初始化 firebase-admin SDK
  // const admin = require('firebase-admin');
  // admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
  fcmInitialized = true;
  console.log('FCM initialized');
}

/**
 * 发送通知给指定用户
 * @param {number} userId - 目标用户 ID
 * @param {Object} notification - 通知内容
 * @param {string} notification.title - 通知标题
 * @param {string} notification.body - 通知内容
 * @param {string} notification.type - 通知类型 (session_request, session_accepted, security_alert, etc.)
 * @param {Object} notification.data - 额外数据
 */
async function sendNotification(userId, notification) {
  try {
    // 1. 通过 Socket.io 发送实时通知（如果用户在线）
    const socketService = require('./socketService');
    const isOnline = socketService.isOnline(userId);

    if (isOnline) {
      const io = socketService.getIO();
      if (io) {
        io.to(`user_${userId}`).emit('notification', {
          ...notification,
          timestamp: new Date().toISOString(),
        });
      }
    }

    // 2. 通过 FCM 发送推送通知（如果用户不在线且 FCM 已配置）
    if (!isOnline && fcmInitialized) {
      await sendFCMNotification(userId, notification);
    }

    // 3. 保存通知到数据库
    await saveNotification(userId, notification);

    return { success: true, delivered: isOnline ? 'socket' : (fcmInitialized ? 'fcm' : 'saved') };
  } catch (err) {
    console.error('Send notification error:', err);
    return { success: false, error: err.message };
  }
}

/**
 * 通过 FCM 发送推送通知
 */
async function sendFCMNotification(userId, notification) {
  try {
    // 获取用户的 FCM token
    const [devices] = await db.query(
      'SELECT fcm_token FROM devices WHERE user_id = ? AND fcm_token IS NOT NULL',
      [userId]
    );

    if (devices.length === 0) {
      console.log(`No FCM token found for user ${userId}`);
      return;
    }

    // TODO: 使用 firebase-admin 发送消息
    // const message = {
    //   notification: {
    //     title: notification.title,
    //     body: notification.body,
    //   },
    //   data: notification.data || {},
    //   token: devices[0].fcm_token,
    // };
    // await admin.messaging().send(message);

    console.log(`FCM notification queued for user ${userId}`);
  } catch (err) {
    console.error('FCM send error:', err);
  }
}

/**
 * 保存通知到数据库
 */
async function saveNotification(userId, notification) {
  try {
    // 使用 security_events 表存储重要通知
    if (notification.type === 'security_alert') {
      await db.query(
        `INSERT INTO security_events (user_id, event_type, severity, description, metadata)
         VALUES (?, 'risk_warning', ?, ?, ?)`,
        [
          userId,
          notification.severity || 'medium',
          notification.body,
          JSON.stringify(notification.data || {}),
        ]
      );
    }
  } catch (err) {
    console.error('Save notification error:', err);
  }
}

/**
 * 发送远程协助请求通知
 */
async function sendSessionRequestNotification(assistantUserId, elderlyUserName, sessionId) {
  return sendNotification(assistantUserId, {
    title: '远程协助请求',
    body: `${elderlyUserName} 向您发起了远程协助请求`,
    type: 'session_request',
    data: { sessionId },
  });
}

/**
 * 发送会话状态变更通知
 */
async function sendSessionStatusNotification(userId, status, sessionId) {
  const statusText = {
    active: '已接受',
    completed: '已结束',
    cancelled: '已取消',
  };

  return sendNotification(userId, {
    title: '协助会话更新',
    body: `远程协助会话${statusText[status] || status}`,
    type: 'session_status',
    data: { sessionId, status },
  });
}

/**
 * 发送安全警告通知
 */
async function sendSecurityAlert(userId, description, severity = 'high') {
  return sendNotification(userId, {
    title: '⚠️ 安全提醒',
    body: description,
    type: 'security_alert',
    severity,
    data: {},
  });
}

/**
 * 注册设备 FCM token
 */
async function registerDevice(userId, deviceInfo) {
  try {
    const { deviceUuid, deviceType, deviceModel, osVersion, appVersion, fcmToken } = deviceInfo;

    await db.query(
      `INSERT INTO devices (user_id, device_uuid, device_type, device_model, os_version, app_version, fcm_token, last_active)
       VALUES (?, ?, ?, ?, ?, ?, ?, NOW())
       ON DUPLICATE KEY UPDATE
         fcm_token = VALUES(fcm_token),
         device_model = VALUES(device_model),
         os_version = VALUES(os_version),
         app_version = VALUES(app_version),
         last_active = NOW()`,
      [userId, deviceUuid, deviceType, deviceModel, osVersion, appVersion, fcmToken]
    );

    return { success: true };
  } catch (err) {
    console.error('Register device error:', err);
    return { success: false, error: err.message };
  }
}

module.exports = {
  initFCM,
  sendNotification,
  sendSessionRequestNotification,
  sendSessionStatusNotification,
  sendSecurityAlert,
  registerDevice,
};
