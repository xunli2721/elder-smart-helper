const { Server } = require('socket.io');
const jwt = require('jsonwebtoken');
const db = require('../config/db');
const logger = require('../utils/logger');

const JWT_SECRET = process.env.JWT_SECRET || '';

let io;

// 存储在线用户 { userId: socketId }
const onlineUsers = new Map();
// 存储用户加入的会话 { userId: Set<sessionId> }
const userSessions = new Map();

// 校验用户是否属于该会话
async function isSessionMember(userId, sessionId) {
  try {
    const [rows] = await db.query(
      'SELECT id FROM remote_sessions WHERE id = ? AND (elderly_user_id = ? OR assistant_user_id = ?)',
      [sessionId, userId, userId]
    );
    return rows.length > 0;
  } catch (err) {
    logger.error('Session membership check failed', { error: err.message });
    return false;
  }
}

function initialize(server) {
  // CORS: 从环境变量读取，不再硬编码 *
  const corsOrigin = process.env.CORS_ORIGIN || '*';

  io = new Server(server, {
    cors: {
      origin: corsOrigin === '*' ? true : corsOrigin.split(',').map(o => o.trim()),
      methods: ['GET', 'POST'],
    },
  });

  // Socket.IO 连接认证中间件
  io.use((socket, next) => {
    const token = socket.handshake.auth?.token;
    if (!token) {
      return next(new Error('未提供认证令牌'));
    }
    try {
      const decoded = jwt.verify(token, JWT_SECRET);
      socket.user = decoded;
      next();
    } catch (err) {
      return next(new Error('认证失败'));
    }
  });

  io.on('connection', (socket) => {
    const userId = socket.user?.id;
    logger.info('Client connected', { socketId: socket.id, userId });

    // 用户上线 — 使用 JWT 中的 userId，不信任客户端传值
    if (userId) {
      onlineUsers.set(String(userId), socket.id);
    }

    // user_online 事件已不再需要，上线在 connection 时自动处理
    // 保留兼容：忽略客户端传入的 uid，只用 JWT 身份
    socket.on('user_online', () => {
      if (userId) {
        onlineUsers.set(String(userId), socket.id);
        logger.info('User online', { userId });
      }
    });

    // 加入会话房间（校验用户是否属于该会话）
    socket.on('join_session', async (sessionId) => {
      const sid = parseInt(sessionId);
      if (isNaN(sid) || sid <= 0) return;

      if (!userId || !(await isSessionMember(userId, sid))) {
        logger.warn('Unauthorized join_session attempt', { userId, sessionId: sid });
        return;
      }

      socket.join(`session_${sid}`);
      if (!userSessions.has(String(userId))) {
        userSessions.set(String(userId), new Set());
      }
      userSessions.get(String(userId)).add(String(sid));
      logger.debug('User joined session', { socketId: socket.id, userId, sessionId: sid });
    });

    // 通用会话事件处理（带权限校验）
    function handleSessionEvent(eventName, data, handler) {
      const sid = parseInt(data?.sessionId);
      if (isNaN(sid) || sid <= 0) return;
      if (!userSessions.get(String(userId))?.has(String(sid))) {
        logger.warn(`Unauthorized ${eventName} attempt`, { userId, sessionId: sid });
        return;
      }
      handler(sid);
    }

    // 发送截图
    socket.on('screenshot', (data) => {
      handleSessionEvent('screenshot', data, (sid) => {
        socket.to(`session_${sid}`).emit('screenshot', data);
        saveMessage(sid, userId, 'screenshot', null, data.image);
      });
    });

    // 发送标注
    socket.on('annotation', (data) => {
      handleSessionEvent('annotation', data, (sid) => {
        socket.to(`session_${sid}`).emit('annotation', data);
        const imageData = data.annotation?.imageBase64 || null;
        saveMessage(sid, userId, 'annotation', null, imageData);
      });
    });

    // 发送文字消息
    socket.on('message', (data) => {
      handleSessionEvent('message', data, (sid) => {
        socket.to(`session_${sid}`).emit('message', data);
        saveMessage(sid, userId, 'text', data.message, null);
      });
    });

    // 结束会话
    socket.on('end_session', async (data) => {
      handleSessionEvent('end_session', data, async (sid) => {
        io.to(`session_${sid}`).emit('session_ended', { sessionId: sid });
        try {
          await db.query(
            `UPDATE remote_sessions SET status = 'completed', ended_at = NOW()
             WHERE id = ? AND status IN ('requested', 'active')`,
            [sid]
          );
        } catch (err) {
          logger.error('Failed to update session on end', { error: err.message });
        }
        const sessions = userSessions.get(String(userId));
        if (sessions) sessions.delete(String(sid));
      });
    });

    // 发送教程卡片
    socket.on('tutorial', (data) => {
      handleSessionEvent('tutorial', data, (sid) => {
        socket.to(`session_${sid}`).emit('tutorial', data);
        const tutorialData = data.tutorial ? JSON.stringify(data.tutorial) : null;
        saveMessage(sid, userId, 'tutorial', tutorialData, null);
      });
    });

    // 发送引导标记
    socket.on('guide_mark', (data) => {
      handleSessionEvent('guide_mark', data, (sid) => {
        socket.to(`session_${sid}`).emit('guide_mark', data);
        const markData = data.mark ? JSON.stringify(data.mark) : null;
        saveMessage(sid, userId, 'guide_mark', markData, null);
      });
    });

    // 确认引导完成
    socket.on('guide_confirm', (data) => {
      handleSessionEvent('guide_confirm', data, (sid) => {
        socket.to(`session_${sid}`).emit('guide_confirm', data);
      });
    });

    // 屏幕共享帧
    socket.on('screen_frame', (data) => {
      handleSessionEvent('screen_frame', data, (sid) => {
        socket.to(`session_${sid}`).emit('screen_frame', data);
      });
    });

    // 断开连接
    socket.on('disconnect', async () => {
      if (userId) {
        if (onlineUsers.get(String(userId)) === socket.id) {
          onlineUsers.delete(String(userId));
        }

        // 自动关闭该用户的所有进行中会话
        const sessions = userSessions.get(String(userId));
        if (sessions && sessions.size > 0) {
          for (const sessionId of sessions) {
            try {
              await db.query(
                `UPDATE remote_sessions SET status = 'completed', ended_at = NOW()
                 WHERE id = ? AND status = 'active'`,
                [sessionId]
              );
              io.to(`session_${sessionId}`).emit('session_ended', {
                sessionId: parseInt(sessionId),
                reason: 'disconnected',
              });
              logger.info('Auto-closed session on disconnect', { userId, sessionId });
            } catch (err) {
              logger.error('Failed to auto-close session', { error: err.message, sessionId });
            }
          }
          userSessions.delete(String(userId));
        }
      }
      logger.info('Client disconnected', { socketId: socket.id, userId });
    });
  });

  logger.info('Socket.io initialized');
}

function getIO() {
  return io;
}

/// 检查单个用户是否在线
function isOnline(userId) {
  return onlineUsers.has(String(userId));
}

/// 批量查询用户在线状态，返回 { userId: true/false }
function getOnlineStatus(userIds) {
  const result = {};
  for (const id of userIds) {
    result[String(id)] = onlineUsers.has(String(id));
  }
  return result;
}

/// 保存消息到数据库
async function saveMessage(sessionId, senderId, messageType, content, imageData) {
  try {
    await db.query(
      `INSERT INTO chat_messages (session_id, sender_id, message_type, content, image_data)
       VALUES (?, ?, ?, ?, ?)`,
      [sessionId, senderId, messageType, content, imageData]
    );
  } catch (err) {
    logger.error('Save message failed', { error: err.message });
  }
}

/// 获取会话的历史消息
async function getSessionMessages(sessionId, { page = 1, pageSize = 50 } = {}) {
  const pageNum = Math.max(1, parseInt(page) || 1);
  const size = Math.min(Math.max(1, parseInt(pageSize) || 50), 100);
  const offset = (pageNum - 1) * size;

  const [messages] = await db.query(
    `SELECT cm.*, u.name as sender_name
     FROM chat_messages cm
     JOIN users u ON cm.sender_id = u.id
     WHERE cm.session_id = ?
     ORDER BY cm.created_at ASC
     LIMIT ? OFFSET ?`,
    [sessionId, size, offset]
  );

  return messages;
}

module.exports = { initialize, getIO, isOnline, getOnlineStatus, getSessionMessages };
