const { Server } = require('socket.io');

let io;

// 存储在线用户 { userId: socketId }
const onlineUsers = new Map();

function initialize(server) {
  io = new Server(server, {
    cors: {
      origin: '*',
      methods: ['GET', 'POST']
    }
  });

  io.on('connection', (socket) => {
    console.log('Client connected:', socket.id);

    // 用户上线
    socket.on('user_online', (userId) => {
      onlineUsers.set(String(userId), socket.id);
      console.log(`User ${userId} online`);
    });

    // 加入会话房间
    socket.on('join_session', (sessionId) => {
      socket.join(`session_${sessionId}`);
      console.log(`Socket ${socket.id} joined session ${sessionId}`);
    });

    // 发送截图
    socket.on('screenshot', (data) => {
      socket.to(`session_${data.sessionId}`).emit('screenshot', data);
    });

    // 发送标注
    socket.on('annotation', (data) => {
      socket.to(`session_${data.sessionId}`).emit('annotation', data);
    });

    // 发送文字消息
    socket.on('message', (data) => {
      socket.to(`session_${data.sessionId}`).emit('message', data);
    });

    // 结束会话
    socket.on('end_session', (data) => {
      io.to(`session_${data.sessionId}`).emit('session_ended', data);
    });

    // 断开连接
    socket.on('disconnect', () => {
      for (const [userId, socketId] of onlineUsers.entries()) {
        if (socketId === socket.id) {
          onlineUsers.delete(userId);
          break;
        }
      }
      console.log('Client disconnected:', socket.id);
    });
  });

  console.log('Socket.io initialized');
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

module.exports = { initialize, getIO, isOnline, getOnlineStatus };