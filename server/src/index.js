const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const http = require('http');
const swaggerUi = require('swagger-ui-express');
const swaggerSpec = require('./config/swagger');

dotenv.config();

// 启动时校验关键环境变量（仅在直接运行时检查，测试环境由 jest 设置）
if (!process.env.JWT_SECRET && require.main === module) {
  console.error('FATAL ERROR: JWT_SECRET is not defined in environment variables.');
  console.error('Please set JWT_SECRET in your .env file.');
  process.exit(1);
}

// 测试环境下设置默认 JWT_SECRET（如果 .env 未加载）
if (!process.env.JWT_SECRET) {
  process.env.JWT_SECRET = 'test_jwt_secret_for_testing';
}

const authRoutes = require('./routes/auth.routes');
const userRoutes = require('./routes/user.routes');
const tutorialRoutes = require('./routes/tutorial.routes');
const remoteRoutes = require('./routes/remote.routes');
const securityRoutes = require('./routes/security.routes');
const { verifyToken } = require('./middleware/auth');
const socketService = require('./services/socketService');

const app = express();
const server = http.createServer(app);
const PORT = process.env.PORT || 3000;

// CORS 配置：从环境变量读取允许的来源
let corsOptions;
if (process.env.CORS_ORIGIN === '*') {
  corsOptions = {
    origin: true, // 允许所有来源
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  };
} else {
  const corsOrigins = process.env.CORS_ORIGIN
    ? process.env.CORS_ORIGIN.split(',').map(o => o.trim())
    : ['http://localhost:3000', 'http://localhost:3001', 'http://localhost:8080'];
  corsOptions = {
    origin: corsOrigins,
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  };
}

app.use(cors(corsOptions));

app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// 简易内存限流器（保护认证接口）
const rateLimitStore = new Map();

function rateLimit({ windowMs = 15 * 60 * 1000, max = 100 } = {}) {
  return (req, res, next) => {
    const key = req.ip;
    const now = Date.now();
    const entry = rateLimitStore.get(key);

    if (!entry || now - entry.start > windowMs) {
      rateLimitStore.set(key, { start: now, count: 1 });
      return next();
    }

    entry.count++;
    if (entry.count > max) {
      return res.status(429).json({ success: false, message: '请求过于频繁，请稍后再试' });
    }
    next();
  };
}

// 定期清理过期的限流记录（仅在直接运行时启动）
if (require.main === module) {
  setInterval(() => {
    const now = Date.now();
    for (const [key, entry] of rateLimitStore.entries()) {
      if (now - entry.start > 30 * 60 * 1000) {
        rateLimitStore.delete(key);
      }
    }
  }, 5 * 60 * 1000);
}

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', time: new Date().toISOString() });
});

// Swagger API 文档
app.use('/api/docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec, {
  customCss: '.swagger-ui .topbar { display: none }',
  customSiteTitle: 'ElderSmartHelper API 文档',
}));

// 认证接口加限流（每 15 分钟最多 20 次）
app.use('/api/auth', rateLimit({ windowMs: 15 * 60 * 1000, max: 20 }), authRoutes);

// API routes
app.use('/api/users', verifyToken, userRoutes);
app.use('/api/tutorials', tutorialRoutes);
app.use('/api/remote', verifyToken, rateLimit({ windowMs: 15 * 60 * 1000, max: 60 }), remoteRoutes);
app.use('/api/security', verifyToken, securityRoutes);

// 全局错误处理中间件
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({ success: false, message: '服务器内部错误' });
});

// Start server only when run directly (not when required by tests)
if (require.main === module) {
  socketService.initialize(server);
  server.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
    const origins = corsOptions.origin === true ? '*' : (Array.isArray(corsOptions.origin) ? corsOptions.origin.join(', ') : corsOptions.origin);
    console.log(`CORS allowed origins: ${origins}`);
  });
}

module.exports = { app, server };