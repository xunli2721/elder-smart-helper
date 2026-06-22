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

describe('Users API Integration', () => {
  describe('POST /api/users/bind', () => {
    test('should bind family successfully', async () => {
      db.query
        .mockResolvedValueOnce([[{ id: 2, name: '小张', user_type: 'family' }]])
        .mockResolvedValueOnce([[]])
        .mockResolvedValueOnce([{ insertId: 1 }]);

      const res = await request(app)
        .post('/api/users/bind')
        .set('Authorization', `Bearer ${elderlyToken}`)
        .send({ phone: '13900000000', relationship: 'child' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.message).toBe('绑定成功');
    });

    test('should return 401 without token', async () => {
      const res = await request(app)
        .post('/api/users/bind')
        .send({ phone: '13900000000' });

      expect(res.status).toBe(401);
    });

    test('should return 400 for missing phone', async () => {
      const res = await request(app)
        .post('/api/users/bind')
        .set('Authorization', `Bearer ${elderlyToken}`)
        .send({});

      expect(res.status).toBe(400);
      expect(res.body.message).toBe('请输入家人手机号');
    });
  });

  describe('GET /api/users/family', () => {
    test('should return family list for elderly user', async () => {
      db.query.mockResolvedValueOnce([[
        { id: 2, name: '小张', phone: '13900000000', user_type: 'family', relationship: 'child' }
      ]]);

      const res = await request(app)
        .get('/api/users/family')
        .set('Authorization', `Bearer ${elderlyToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveLength(1);
    });

    test('should return 401 without token', async () => {
      const res = await request(app).get('/api/users/family');

      expect(res.status).toBe(401);
    });
  });

  describe('DELETE /api/users/family/:id', () => {
    test('should unbind family successfully', async () => {
      db.query.mockResolvedValueOnce([{ affectedRows: 1 }]);

      const res = await request(app)
        .delete('/api/users/family/1')
        .set('Authorization', `Bearer ${elderlyToken}`);

      expect(res.status).toBe(200);
      expect(res.body.message).toBe('解除绑定成功');
    });

    test('should return 404 for non-existent relationship', async () => {
      db.query.mockResolvedValueOnce([{ affectedRows: 0 }]);

      const res = await request(app)
        .delete('/api/users/family/999')
        .set('Authorization', `Bearer ${elderlyToken}`);

      expect(res.status).toBe(404);
    });
  });

  describe('PUT /api/users/settings', () => {
    test('should update settings successfully', async () => {
      db.query.mockResolvedValueOnce([{ affectedRows: 1 }]);

      const res = await request(app)
        .put('/api/users/settings')
        .set('Authorization', `Bearer ${elderlyToken}`)
        .send({ name: '新名字', font_size: 'xlarge' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });

    test('should return 400 for empty body', async () => {
      const res = await request(app)
        .put('/api/users/settings')
        .set('Authorization', `Bearer ${elderlyToken}`)
        .send({});

      expect(res.status).toBe(400);
      expect(res.body.message).toBe('没有要更新的内容');
    });

    test('should return 401 without token', async () => {
      const res = await request(app)
        .put('/api/users/settings')
        .send({ name: 'test' });

      expect(res.status).toBe(401);
    });
  });
});
