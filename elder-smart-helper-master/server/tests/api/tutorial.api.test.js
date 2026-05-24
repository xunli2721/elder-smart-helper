const request = require('supertest');
const app = require('../../src/index').app;
const db = require('../../src/config/db');

let server;
let adminToken, userToken;
const testSteps = [
  { title: '步骤一', description: '第一步的操作说明', image: '', order: 1 },
  { title: '步骤二', description: '第二步的操作说明', image: '', order: 2 },
];

beforeAll((done) => {
  server = app.listen(0, done);
});

afterAll(async () => {
  await db.query('DELETE FROM tutorials');
  await db.query('DELETE FROM family_relationships');
  await db.query('DELETE FROM users');
  if (server) server.close();
  await db.end();
});

beforeEach(async () => {
  await db.query('DELETE FROM tutorials');
  await db.query('DELETE FROM family_relationships');
  await db.query('DELETE FROM users');

  // 创建管理员
  const aRes = await request(app)
    .post('/api/auth/register')
    .send({ phone: '13700001111', password: '123456', name: '王管理员', user_type: 'admin' });
  adminToken = aRes.body.data.token;

  // 创建普通用户
  const uRes = await request(app)
    .post('/api/auth/register')
    .send({ phone: '13800001111', password: '123456', name: '张大爷', user_type: 'elderly' });
  userToken = uRes.body.data.token;
});

describe('Tutorial API', () => {
  describe('POST /api/tutorials (管理员)', () => {
    test('管理员应能创建教程', async () => {
      const res = await request(app)
        .post('/api/tutorials')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          title: '测试教程',
          description: '这是一个测试教程',
          category: 'basic',
          difficulty_level: 'beginner',
          steps: testSteps,
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveProperty('id');
    });

    test('普通用户不能创建教程', async () => {
      const res = await request(app)
        .post('/api/tutorials')
        .set('Authorization', `Bearer ${userToken}`)
        .send({
          title: '测试教程',
          category: 'basic',
          steps: testSteps,
        });

      expect(res.status).toBe(403);
      expect(res.body.success).toBe(false);
    });

    test('未登录不能创建教程', async () => {
      const res = await request(app)
        .post('/api/tutorials')
        .send({
          title: '测试教程',
          category: 'basic',
          steps: testSteps,
        });

      expect(res.status).toBe(401);
    });

    test('缺少必填字段应返回 400', async () => {
      const res = await request(app)
        .post('/api/tutorials')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ title: '缺少字段' });

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
    });
  });

  describe('GET /api/tutorials', () => {
    beforeEach(async () => {
      await request(app)
        .post('/api/tutorials')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ title: '基础教程', description: 'base', category: 'basic', steps: testSteps });
      await request(app)
        .post('/api/tutorials')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ title: '支付教程', description: 'pay', category: 'payment', steps: testSteps });
    });

    test('应返回所有教程', async () => {
      const res = await request(app).get('/api/tutorials');

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.length).toBe(2);
    });

    test('应按分类筛选', async () => {
      const res = await request(app)
        .get('/api/tutorials')
        .query({ category: 'basic' });

      expect(res.status).toBe(200);
      expect(res.body.data.length).toBe(1);
      expect(res.body.data[0].title).toBe('基础教程');
    });
  });

  describe('GET /api/tutorials/:id', () => {
    let tutorialId;

    beforeEach(async () => {
      const res = await request(app)
        .post('/api/tutorials')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ title: '测试教程', description: 'detail', category: 'basic', steps: testSteps });
      tutorialId = res.body.data.id;
    });

    test('应返回教程详情', async () => {
      const res = await request(app).get(`/api/tutorials/${tutorialId}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.title).toBe('测试教程');
      expect(Array.isArray(res.body.data.steps)).toBe(true);
      expect(res.body.data.steps.length).toBe(2);
    });

    test('不存在的教程应返回 404', async () => {
      const res = await request(app).get('/api/tutorials/99999');

      expect(res.status).toBe(404);
      expect(res.body.success).toBe(false);
    });
  });

  describe('PUT /api/tutorials/:id', () => {
    let tutorialId;

    beforeEach(async () => {
      const res = await request(app)
        .post('/api/tutorials')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ title: '原始标题', category: 'basic', steps: testSteps });
      tutorialId = res.body.data.id;
    });

    test('管理员应能更新教程', async () => {
      const res = await request(app)
        .put(`/api/tutorials/${tutorialId}`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ title: '更新后的标题', category: 'communication', steps: testSteps });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });
  });

  describe('DELETE /api/tutorials/:id', () => {
    let tutorialId;

    beforeEach(async () => {
      const res = await request(app)
        .post('/api/tutorials')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ title: '待删除教程', category: 'basic', steps: testSteps });
      tutorialId = res.body.data.id;
    });

    test('管理员应能删除教程', async () => {
      const res = await request(app)
        .delete(`/api/tutorials/${tutorialId}`)
        .set('Authorization', `Bearer ${adminToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });

    test('普通用户不能删除教程', async () => {
      const res = await request(app)
        .delete(`/api/tutorials/${tutorialId}`)
        .set('Authorization', `Bearer ${userToken}`);

      expect(res.status).toBe(403);
    });
  });

  describe('POST /api/tutorials/:id/view', () => {
    let tutorialId;

    beforeEach(async () => {
      const res = await request(app)
        .post('/api/tutorials')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ title: '浏览测试', category: 'basic', steps: testSteps });
      tutorialId = res.body.data.id;
    });

    test('浏览量应递增', async () => {
      await request(app).post(`/api/tutorials/${tutorialId}/view`);
      await request(app).post(`/api/tutorials/${tutorialId}/view`);

      const res = await request(app).get(`/api/tutorials/${tutorialId}`);
      expect(res.body.data.views_count).toBe(2);
    });
  });
});
