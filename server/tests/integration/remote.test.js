const request = require('supertest');
const jwt = require('jsonwebtoken');
const db = require('../../src/config/db');
const { JWT_SECRET } = require('../../src/middleware/auth');

jest.mock('../../src/config/db');

const { app } = require('../../src/index.js');
const elderlyToken = jwt.sign({ id: 1, phone: '13800138000', user_type: 'elderly' }, JWT_SECRET, { expiresIn: '7d' });
const familyToken = jwt.sign({ id: 2, phone: '13900000000', user_type: 'family' }, JWT_SECRET, { expiresIn: '7d' });

afterEach(() => {
  jest.clearAllMocks();
});

describe('Remote API Integration', () => {
  describe('POST /api/remote/request', () => {
    test('should create remote session successfully', async () => {
      db.query
        .mockResolvedValueOnce([[{ id: 1 }]])
        .mockResolvedValueOnce([{ insertId: 10 }]);

      const res = await request(app)
        .post('/api/remote/request')
        .set('Authorization', `Bearer ${elderlyToken}`)
        .send({ assistant_user_id: 2, request_description: '需要帮助' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.session_id).toBe(10);
    });

    test('should return 401 without token', async () => {
      const res = await request(app)
        .post('/api/remote/request')
        .send({ assistant_user_id: 2 });

      expect(res.status).toBe(401);
    });

    test('should return 400 for missing assistant_user_id', async () => {
      const res = await request(app)
        .post('/api/remote/request')
        .set('Authorization', `Bearer ${elderlyToken}`)
        .send({});

      expect(res.status).toBe(400);
      expect(res.body.message).toBe('请选择协助者');
    });

    test('should return 400 when no family relationship', async () => {
      db.query.mockResolvedValueOnce([[]]);

      const res = await request(app)
        .post('/api/remote/request')
        .set('Authorization', `Bearer ${elderlyToken}`)
        .send({ assistant_user_id: 999 });

      expect(res.status).toBe(400);
      expect(res.body.message).toBe('只能向已绑定的家人发起协助');
    });
  });

  describe('GET /api/remote/sessions', () => {
    test('should return sessions for elderly user', async () => {
      db.query.mockResolvedValueOnce([[
        { id: 1, status: 'requested', assistant_name: '小张', created_at: '2026-01-01' }
      ]]);

      const res = await request(app)
        .get('/api/remote/sessions')
        .set('Authorization', `Bearer ${elderlyToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveLength(1);
    });

    test('should return sessions for family user', async () => {
      db.query.mockResolvedValueOnce([[
        { id: 1, status: 'active', elderly_name: '张爷爷', created_at: '2026-01-01' }
      ]]);

      const res = await request(app)
        .get('/api/remote/sessions')
        .set('Authorization', `Bearer ${familyToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });

    test('should return 401 without token', async () => {
      const res = await request(app).get('/api/remote/sessions');

      expect(res.status).toBe(401);
    });
  });

  describe('PUT /api/remote/sessions/:id/status', () => {
    test('should update session status to active', async () => {
      db.query.mockResolvedValueOnce([{ affectedRows: 1 }]);

      const res = await request(app)
        .put('/api/remote/sessions/1/status')
        .set('Authorization', `Bearer ${elderlyToken}`)
        .send({ status: 'active' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });

    test('should update session status to completed', async () => {
      db.query.mockResolvedValueOnce([{ affectedRows: 1 }]);

      const res = await request(app)
        .put('/api/remote/sessions/1/status')
        .set('Authorization', `Bearer ${familyToken}`)
        .send({ status: 'completed' });

      expect(res.status).toBe(200);
    });

    test('should return 400 for invalid status', async () => {
      const res = await request(app)
        .put('/api/remote/sessions/1/status')
        .set('Authorization', `Bearer ${elderlyToken}`)
        .send({ status: 'invalid' });

      expect(res.status).toBe(400);
      expect(res.body.message).toBe('无效的状态');
    });

    test('should return 404 for non-existent session', async () => {
      db.query.mockResolvedValueOnce([{ affectedRows: 0 }]);

      const res = await request(app)
        .put('/api/remote/sessions/999/status')
        .set('Authorization', `Bearer ${elderlyToken}`)
        .send({ status: 'active' });

      expect(res.status).toBe(404);
    });

    test('should return 401 without token', async () => {
      const res = await request(app)
        .put('/api/remote/sessions/1/status')
        .send({ status: 'active' });

      expect(res.status).toBe(401);
    });
  });
});
