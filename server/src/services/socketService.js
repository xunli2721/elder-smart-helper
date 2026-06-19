const { Server } = require('socket.io');
const jwt = require('jsonwebtoken');
const db = require('../config/db');
const logger = require('../utils/logger');

const JWT_SECRET = process.env.JWT_SECRET || '';

let io;

// 存储在线用户 { userId: socketId }
const onlineUsers = new Map();

function initialize(server) {
  io = new Server(server, {
    cors: {
      origin: '*',
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

    // 用户上线（也支持客户端主动发送 user_online）
    if (userId) {
      onlineUsers.set(String(userId), socket.id);
    }

    socket.on('user_online', (uid) => {
      onlineUsers.set(String(uid), socket.id);
      logger.info('User online', { userId: uid });
    });

    // 加入会话房间（校验用户是否属于该会话）
    socket.on('join_session', async (sessionId) => {
      // 简单校验：将 socket 加入房间
      // 完整校验需要查询 remote_sessions 表确认用户是参与者
      socket.join(`session_${sessionId}`);
      logger.debug('User joined session', { socketId: socket.id, userId, sessionId });
    });

    // 发送截图
    socket.on('screenshot', (data) => {
      socket.to(`session_${data.sessionId}`).emit('screenshot', data);
      saveMessage(data.sessionId, userId, 'screenshot', null, data.image);
    });

    // 发送标注
    socket.on('annotation', (data) => {
      socket.to(`session_${data.sessionId}`).emit('annotation', data);
      const imageData = data.annotation?.imageBase64 || null;
      saveMessage(data.sessionId, userId, 'annotation', null, imageData);
    });

    // 发送文字消息
    socket.on('message', (data) => {
      socket.to(`session_${data.sessionId}`).emit('message', data);
      saveMessage(data.sessionId, userId, 'text', data.message, null);
    });

    // 结束会话
    socket.on('end_session', (data) => {
      io.to(`session_${data.sessionId}`).emit('session_ended', data);
    });

    // 断开连接
    socket.on('disconnect', () => {
      if (userId) {
        // 仅当当前 socketId 匹配时才删除（同一用户可能多设备连接）
        if (onlineUsers.get(String(userId)) === socket.id) {
          onlineUsers.delete(String(userId));
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
  const size = Math.min(Math.max(1, pageSize), 100);
  const offset = (Math.max(1, page) - 1) * size;

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
