# ElderSmartHelper - Backend Server

## Overview
This is the backend server for ElderSmartHelper, providing RESTful APIs, WebSocket connections for remote assistance, AI service integration, user management, and data storage.

## Features
- User authentication and authorization
- Device binding and remote assistance management
- AI service integration (speech recognition, fraud detection)
- Real-time communication via WebSocket
- Database operations and data persistence
- Security monitoring and risk detection

## Technology Stack
- **Runtime**: Node.js (v16+) / Python (3.8+)
- **Framework**: Express.js / FastAPI
- **Database**: MySQL + Redis
- **Message Queue**: RabbitMQ / Redis PubSub
- **Real-time**: WebSocket (Socket.io)
- **AI Integration**: TensorFlow Serving / PyTorch / Cloud AI APIs

## Project Structure
```
server/
├── src/
│   ├── controllers/     # Request handlers
│   ├── models/          # Database models
│   ├── routes/          # API routes
│   ├── middleware/      # Custom middleware
│   ├── services/        # Business logic
│   ├── utils/          # Utility functions
│   └── config/         # Configuration
├── tests/              # Test files
├── docs/              # API documentation
└── scripts/           # Deployment scripts
```

## Getting Started

### Prerequisites
- Node.js v16+ or Python 3.8+
- MySQL 8.0+
- Redis 6.0+

### Installation
1. Install dependencies:
   ```bash
   npm install
   # or
   pip install -r requirements.txt
   ```

2. Configure environment variables:
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

3. Set up database:
   ```bash
   mysql -u root -p < database/schema.sql
   ```

4. Start the server:
   ```bash
   npm start
   # or
   python app.py
   ```

### API Documentation
API documentation is available at `/api/docs` when the server is running.

## Development
- Code style: ESLint (JavaScript) / Black (Python)
- Testing: Jest / Pytest
- Commit messages: Conventional Commits

## Deployment
See [DEPLOYMENT.md](DEPLOYMENT.md) for deployment instructions.

## License
MIT