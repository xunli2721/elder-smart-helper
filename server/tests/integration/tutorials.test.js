const request = require('supertest');
const jwt = require('jsonwebtoken');
const db = require('../../src/config/db');
const { JWT_SECRET } = require('../../src/middleware/auth');

jest.mock('../../src/config/db');

const { app } = require('../../src/index.js');
const adminToken = jwt.sign({ id: 3, phone: '13800138002', user_type: 'admin' }, JWT_SECRET, { expiresIn: '7d' });

afterEach(() => {
  jest.clearAllMocks();
});

describe('Tutorials API Integration', () => {
  describe('GET /api/tutorials', () => {
    test('should return all tutorials', async () => {
      db.query.mockResolvedValueOnce([[
        { id: 1, title: '打电话', category: 'basic', steps: '[{"step":1}]' },
        { id: 2, title: '微信', category: 'communication', steps: '[{"step":1}]' }
      ]]);

      const res = await request(app).get('/api/tutorials');

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveLength(2);
    });

    test('should filter by category', async () => {
      db.query.mockResolvedValueOnce([[{ id: 1, title: '打电话', category: 'basic', steps: '[]' }]]);

      const res = await request(app).get('/api/tutorials?category=basic');

      expect(res.status).toBe(200);
    });
  });

  describe('GET /api/tutorials/:id', () => {
    test('should return tutorial by id', async () => {
      db.query.mockResolvedValueOnce([[{
        id: 1, title: '打电话', category: 'basic',
        steps: '[{"step":1,"title":"步骤1","description":"拨号"}]'
      }]]);

      const res = await request(app).get('/api/tutorials/1');

      expect(res.status).toBe(200);
      expect(res.body.data.title).toBe('打电话');
    });

    test('should return 404 for non-existent tutorial', async () => {
      db.query.mockResolvedValueOnce([[]]);

      const res = await request(app).get('/api/tutorials/999');

      expect(res.status).toBe(404);
    });
  });

  describe('POST /api/tutorials', () => {
    test('should create tutorial with valid token', async () => {
      db.query.mockResolvedValueOnce([{ insertId: 5 }]);

      const res = await request(app)
        .post('/api/tutorials')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          title: '新教程', category: 'basic',
          steps: [{ step: 1, title: '步骤1', description: '说明' }]
        });

      expect(res.status).toBe(200);
      expect(res.body.data.id).toBe(5);
    });

    test('should return 401 without token', async () => {
      const res = await request(app)
        .post('/api/tutorials')
        .send({ title: 'Test', category: 'basic', steps: [] });

      expect(res.status).toBe(401);
    });

    test('should return 400 for missing required fields', async () => {
      const res = await request(app)
        .post('/api/tutorials')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ title: 'Test' });

      expect(res.status).toBe(400);
    });
  });

  describe('PUT /api/tutorials/:id', () => {
    test('should update tutorial', async () => {
      db.query.mockResolvedValueOnce([{ affectedRows: 1 }]);

      const res = await request(app)
        .put('/api/tutorials/1')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          title: '更新', description: 'd', category: 'basic',
          difficulty_level: 'beginner', image_url: '', steps: []
        });

      expect(res.status).toBe(200);
      expect(res.body.message).toBe('更新成功');
    });

    test('should return 404 for non-existent tutorial', async () => {
      db.query.mockResolvedValueOnce([{ affectedRows: 0 }]);

      const res = await request(app)
        .put('/api/tutorials/999')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          title: 'x', description: '', category: 'basic',
          difficulty_level: 'beginner', image_url: '', steps: []
        });

      expect(res.status).toBe(404);
    });
  });

  describe('DELETE /api/tutorials/:id', () => {
    test('should delete tutorial', async () => {
      db.query.mockResolvedValueOnce([{ affectedRows: 1 }]);

      const res = await request(app)
        .delete('/api/tutorials/1')
        .set('Authorization', `Bearer ${adminToken}`);

      expect(res.status).toBe(200);
      expect(res.body.message).toBe('删除成功');
    });

    test('should return 404 for non-existent tutorial', async () => {
      db.query.mockResolvedValueOnce([{ affectedRows: 0 }]);

      const res = await request(app)
        .delete('/api/tutorials/999')
        .set('Authorization', `Bearer ${adminToken}`);

      expect(res.status).toBe(404);
    });
  });
});
