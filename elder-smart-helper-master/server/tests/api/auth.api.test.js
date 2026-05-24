const request = require('supertest');
const app = require('../../src/index').app;
const db = require('../../src/config/db');

let server;

beforeAll((done) => {
  server = app.listen(0, done);
});

afterAll(async () => {
  await db.query('DELETE FROM family_relationships');
  await db.query('DELETE FROM users');
  if (server) server.close();
  await db.end();
});

beforeEach(async () => {
  await db.query('DELETE FROM family_relationships');
  await db.query('DELETE FROM users');
});

describe('Auth API', () => {
  const testPhone = '13800009999';
  const testPassword = '123456';
  const testName = '测试用户';

  describe('POST /api/auth/register', () => {
    test('应该注册新用户', async () => {
      const res = await request(app)
        .post('/api/auth/register')
        .send({ phone: testPhone, password: testPassword, name: testName, user_type: 'elderly' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveProperty('token');
      expect(res.body.data.user.name).toBe(testName);
    });

    test('缺少必填字段应返回 400', async () => {
      const res = await request(app)
        .post('/api/auth/register')
        .send({ phone: testPhone });

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
    });

    test('手机号格式错误应返回 400', async () => {
      const res = await request(app)
        .post('/api/auth/register')
        .send({ phone: '12345', password: testPassword, name: testName, user_type: 'elderly' });

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
    });

    test('重复注册应返回 400', async () => {
      await request(app)
        .post('/api/auth/register')
        .send({ phone: testPhone, password: testPassword, name: testName, user_type: 'elderly' });

      const res = await request(app)
        .post('/api/auth/register')
        .send({ phone: testPhone, password: testPassword, name: '另一个人', user_type: 'family' });

      expect(res.status).toBe(400);
      expect(res.body.message).toContain('已注册');
    });
  });

  describe('POST /api/auth/login', () => {
    beforeEach(async () => {
      await request(app)
        .post('/api/auth/register')
        .send({ phone: testPhone, password: testPassword, name: testName, user_type: 'elderly' });
    });

    test('应该用正确密码登录', async () => {
      const res = await request(app)
        .post('/api/auth/login')
        .send({ phone: testPhone, password: testPassword });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveProperty('token');
    });

    test('密码错误应返回 400', async () => {
      const res = await request(app)
        .post('/api/auth/login')
        .send({ phone: testPhone, password: 'wrongpassword' });

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
    });

    test('用户不存在应返回 400', async () => {
      const res = await request(app)
        .post('/api/auth/login')
        .send({ phone: '13800000000', password: testPassword });

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
    });
  });

  describe('GET /api/auth/profile', () => {
    let token;

    beforeEach(async () => {
      const res = await request(app)
        .post('/api/auth/register')
        .send({ phone: testPhone, password: testPassword, name: testName, user_type: 'elderly' });
      token = res.body.data.token;
    });

    test('应该返回用户信息', async () => {
      const res = await request(app)
        .get('/api/auth/profile')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.phone).toBe(testPhone);
      expect(res.body.data.name).toBe(testName);
    });

    test('未登录应返回 401', async () => {
      const res = await request(app)
        .get('/api/auth/profile');

      expect(res.status).toBe(401);
    });

    test('无效 Token 应返回 401', async () => {
      const res = await request(app)
        .get('/api/auth/profile')
        .set('Authorization', 'Bearer invalid-token');

      expect(res.status).toBe(401);
      expect(res.body.success).toBe(false);
    });
  });

  describe('PUT /api/auth/password', () => {
    let token;

    beforeEach(async () => {
      const res = await request(app)
        .post('/api/auth/register')
        .send({ phone: testPhone, password: testPassword, name: testName, user_type: 'elderly' });
      token = res.body.data.token;
    });

    test('应该成功修改密码', async () => {
      const res = await request(app)
        .put('/api/auth/password')
        .set('Authorization', `Bearer ${token}`)
        .send({ old_password: testPassword, new_password: 'newpassword' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });

    test('修改密码后能用新密码登录', async () => {
      await request(app)
        .put('/api/auth/password')
        .set('Authorization', `Bearer ${token}`)
        .send({ old_password: testPassword, new_password: 'newpassword' });

      const loginRes = await request(app)
        .post('/api/auth/login')
        .send({ phone: testPhone, password: 'newpassword' });

      expect(loginRes.status).toBe(200);
      expect(loginRes.body.success).toBe(true);
    });

    test('旧密码错误应返回 400', async () => {
      const res = await request(app)
        .put('/api/auth/password')
        .set('Authorization', `Bearer ${token}`)
        .send({ old_password: 'wrong_old', new_password: 'newpassword' });

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
    });
  });

  describe('POST /api/auth/refresh', () => {
    let token;

    beforeEach(async () => {
      const res = await request(app)
        .post('/api/auth/register')
        .send({ phone: testPhone, password: testPassword, name: testName, user_type: 'elderly' });
      token = res.body.data.token;
    });

    test('应该刷新 Token', async () => {
      const res = await request(app)
        .post('/api/auth/refresh')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveProperty('token');
    });
  });
});
