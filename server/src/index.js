const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const dotenv = require('dotenv');

// Load environment variables
dotenv.config();

// Import routes
const authRoutes = require('./routes/auth.routes');
const userRoutes = require('./routes/user.routes');
const tutorialRoutes = require('./routes/tutorial.routes');
const remoteAssistanceRoutes = require('./routes/remoteAssistance.routes');
const securityRoutes = require('./routes/security.routes');

// Import middleware
const errorHandler = require('./middleware/errorHandler');
const notFoundHandler = require('./middleware/notFoundHandler');
const authMiddleware = require('./middleware/auth');

// Import database connection
const db = require('./config/database');
const redisClient = require('./config/redis');
const socketServer = require('./services/socketService');

// Initialize Express app
const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(helmet()); // Security headers
app.use(cors({
  origin: process.env.CORS_ORIGIN || '*',
  credentials: true
}));
app.use(morgan('combined')); // HTTP request logging
app.use(express.json({ limit: '10mb' })); // JSON body parsing
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    service: 'elder-smart-helper-server',
    version: process.env.npm_package_version || '1.0.0'
  });
});

// API routes
app.use('/api/auth', authRoutes);
app.use('/api/users', authMiddleware.verifyToken, userRoutes);
app.use('/api/tutorials', tutorialRoutes);
app.use('/api/remote-assistance', authMiddleware.verifyToken, remoteAssistanceRoutes);
app.use('/api/security', authMiddleware.verifyToken, securityRoutes);

// Documentation
app.get('/api/docs', (req, res) => {
  res.json({
    message: 'API Documentation',
    endpoints: {
      auth: '/api/auth',
      users: '/api/users',
      tutorials: '/api/tutorials',
      remote_assistance: '/api/remote-assistance',
      security: '/api/security'
    },
    version: '1.0.0'
  });
});

// Error handling middleware
app.use(notFoundHandler);
app.use(errorHandler);

// Start server
const server = app.listen(PORT, async () => {
  try {
    // Test database connections
    await db.authenticate();
    console.log('✅ Database connection established successfully.');

    await redisClient.ping();
    console.log('✅ Redis connection established successfully.');

    // Initialize socket server
    socketServer.initialize(server);

    console.log(`🚀 Server is running on port ${PORT}`);
    console.log(`📚 API Documentation available at http://localhost:${PORT}/api/docs`);
    console.log(`🏥 Health check available at http://localhost:${PORT}/health`);
  } catch (error) {
    console.error('❌ Failed to initialize server:', error);
    process.exit(1);
  }
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received. Shutting down gracefully...');
  server.close(async () => {
    try {
      await db.close();
      await redisClient.quit();
      console.log('✅ Server shut down gracefully.');
      process.exit(0);
    } catch (error) {
      console.error('❌ Error during shutdown:', error);
      process.exit(1);
    }
  });
});

process.on('SIGINT', () => {
  console.log('SIGINT received. Shutting down gracefully...');
  server.close(async () => {
    try {
      await db.close();
      await redisClient.quit();
      console.log('✅ Server shut down gracefully.');
      process.exit(0);
    } catch (error) {
      console.error('❌ Error during shutdown:', error);
      process.exit(1);
    }
  });
});

module.exports = { app, server };