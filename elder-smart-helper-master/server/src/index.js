const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const http = require('http');
const path = require('path');

dotenv.config();

const authRoutes = require('./routes/auth.routes');
const userRoutes = require('./routes/user.routes');
const tutorialRoutes = require('./routes/tutorial.routes');
const remoteRoutes = require('./routes/remote.routes');
const { verifyToken } = require('./middleware/auth');
const errorHandler = require('./middleware/errorHandler');
const socketService = require('./services/socketService');
const logger = require('./utils/logger');

const app = express();
const server = http.createServer(app);
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// 静态文件服务（上传的图片）
app.use('/uploads', express.static(path.join(__dirname, '..', 'uploads')));

// 请求日志
app.use((req, _res, next) => {
  logger.info(`${req.method} ${req.path}`, { ip: req.ip });
  next();
});

// Health check
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', time: new Date().toISOString() });
});

// API routes
app.use('/api/auth', authRoutes);
app.use('/api/users', verifyToken, userRoutes);
app.use('/api/tutorials', tutorialRoutes);
app.use('/api/remote', verifyToken, remoteRoutes);

// 404 处理
app.use((_req, res) => {
  res.status(404).json({ success: false, message: '接口不存在' });
});

// 全局错误处理
app.use(errorHandler);

// 仅在直接运行时启动服务器（测试时由测试进程控制）
if (require.main === module) {
  server.listen(PORT, () => {
    socketService.initialize(server);
    logger.info(`Server running on http://localhost:${PORT}`);
  });
}

module.exports = { app, server };
