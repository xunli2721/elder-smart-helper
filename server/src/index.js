const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const http = require('http');

dotenv.config();

const authRoutes = require('./routes/auth.routes');
const userRoutes = require('./routes/user.routes');
const tutorialRoutes = require('./routes/tutorial.routes');
const remoteRoutes = require('./routes/remote.routes');
const { verifyToken } = require('./middleware/auth');
const socketService = require('./services/socketService');

const app = express();
const server = http.createServer(app);
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', time: new Date().toISOString() });
});

// API routes
app.use('/api/auth', authRoutes);
app.use('/api/users', verifyToken, userRoutes);
app.use('/api/tutorials', tutorialRoutes);
app.use('/api/remote', verifyToken, remoteRoutes);

// Start server
server.listen(PORT, () => {
  socketService.initialize(server);
  console.log(`Server running on http://localhost:${PORT}`);
});

module.exports = { app, server };
