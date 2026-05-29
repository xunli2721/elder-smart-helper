const request = require('supertest');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const db = require('../../src/config/db');
const { JWT_SECRET } = require('../../src/middleware/auth');

jest.mock('../../src/config/db');

const { app } = require('../../src/index.js');

afterEach(() => {
  jest.clearAllMocks();
});

describe('Auth API Integration', () => {
  describe('POST /api/auth/register', () => {
    test('should register a new user successfully', async () => {
      db.query
        .mockResolvedValueOnce([[]])
        .mockResolvedValueOnce([{ insertId: 1 }]);

      const res = await request(app)
        .post('/api/auth/register')
        .send({ phone: '13800138001', password: '123456', name: '新用户', user_type: 'elderly' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.token).toBeDefined();
      expect(res.body.data.user.phone).toBe('13800138001');
    });

    test('should return 400 for missing fields', async () => {
      const res = await request(app)
        .post('/api/auth/register')
        .send({ phone: '13800138001' });

      expect(res.status).toBe(400);
      expect(res.body.message).toBe('请填写完整信息');
    });

    test('should return 400 for duplicate phone', async () => {
      db.query.mockResolvedValueOnce([[{ id: 1 }]]);

      const res = await request(app)
        .post('/api/auth/register')
        .send({ phone: '13800138000', password: '123456', name: '测试', user_type: 'elderly' });

      expect(res.status).toBe(400);
      expect(res.body.message).toBe('该手机号已注册');
    });
  });

  describe('POST /api/auth/login', () => {
    test('should login successfully with correct credentials', async () => {
      const hashedPassword = await bcrypt.hash('123456', 10);
      db.query.mockResolvedValueOnce([[{
        id: 1, phone: '13800138000', password: hashedPassword,
        name: '张爷爷', user_type: 'elderly', font_size: 'large'
      }]]);

      const res = await request(app)
        .post('/api/auth/login')
        .send({ phone: '13800138000', password: '123456' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.token).toBeDefined();
      expect(res.body.data.user.name).toBe('张爷爷');
    });

    test('should return 400 for wrong password', async () => {
      const hashedPassword = await bcrypt.hash('123456', 10);
      db.query.mockResolvedValueOnce([[{
        id: 1, phone: '13800138000', password: hashedPassword,
        name: '张爷爷', user_type: 'elderly', font_size: 'large'
      }]]);

      const res = await request(app)
        .post('/api/auth/login')
        .send({ phone: '13800138000', password: 'wrong' });

      expect(res.status).toBe(400);
      expect(res.body.message).toBe('密码错误');
    });

    test('should return 400 for non-existent user', async () => {
      db.query.mockResolvedValueOnce([[]]);

      const res = await request(app)
        .post('/api/auth/login')
        .send({ phone: '99999999999', password: '123456' });

      expect(res.status).toBe(400);
      expect(res.body.message).toBe('用户不存在');
    });
  });

  describe('GET /api/auth/profile', () => {
    test('should return profile with valid token', async () => {
      const token = jwt.sign({ id: 1, phone: '13800138000', user_type: 'elderly' }, JWT_SECRET, { expiresIn: '7d' });
      db.query.mockResolvedValueOnce([[{
        id: 1, phone: '13800138000', name: '张爷爷',
        user_type: 'elderly', font_size: 'large', created_at: '2026-01-01'
      }]]);

      const res = await request(app)
        .get('/api/auth/profile')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.name).toBe('张爷爷');
    });

    test('should return 401 without token', async () => {
      const res = await request(app)
        .get('/api/auth/profile');

      expect(res.status).toBe(401);
      expect(res.body.message).toBe('未登录');
    });

    test('should return 401 with expired token', async () => {
      const token = jwt.sign({ id: 1 }, JWT_SECRET, { expiresIn: '0s' });

      const res = await request(app)
        .get('/api/auth/profile')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(401);
      expect(res.body.message).toBe('登录已过期');
    });
  });
});
