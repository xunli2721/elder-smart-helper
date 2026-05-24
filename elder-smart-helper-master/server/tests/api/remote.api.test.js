const request = require('supertest');
const app = require('../../src/index').app;
const db = require('../../src/config/db');

let server;
let elderlyToken, familyToken, familyId;

beforeAll((done) => {
  server = app.listen(0, done);
});

afterAll(async () => {
  await db.query('DELETE FROM remote_sessions');
  await db.query('DELETE FROM family_relationships');
  await db.query('DELETE FROM users');
  if (server) server.close();
  await db.end();
});

beforeEach(async () => {
  await db.query('DELETE FROM remote_sessions');
  await db.query('DELETE FROM family_relationships');
  await db.query('DELETE FROM users');

  // 创建老人用户
  const eRes = await request(app)
    .post('/api/auth/register')
    .send({ phone: '13800001111', password: '123456', name: '张大爷', user_type: 'elderly' });
  elderlyToken = eRes.body.data.token;

  // 创建家人用户
  const fRes = await request(app)
    .post('/api/auth/register')
    .send({ phone: '13900001111', password: '123456', name: '张小明', user_type: 'family' });
  familyToken = fRes.body.data.token;
  familyId = fRes.body.data.user.id;

  // 建立绑定关系
  await request(app)
    .post('/api/users/bind')
    .set('Authorization', `Bearer ${elderlyToken}`)
    .send({ phone: '13900001111', relationship: 'child' });
});

describe('Remote API', () => {
  describe('POST /api/remote/request', () => {
    test('老人可向已绑定家人发起协助请求', async () => {
      const res = await request(app)
        .post('/api/remote/request')
        .set('Authorization', `Bearer ${elderlyToken}`)
        .send({ assistant_user_id: familyId, request_description: '帮我看看微信怎么打开' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveProperty('session_id');
      expect(res.body.data).toHaveProperty('session_uuid');
    });

    test('不能向未绑定用户发起请求', async () => {
      // 创建另一个未绑定的用户
      const otherRes = await request(app)
        .post('/api/auth/register')
        .send({ phone: '13900002222', password: '123456', name: '陌生人', user_type: 'family' });
      const otherId = otherRes.body.data.user.id;

      const res = await request(app)
        .post('/api/remote/request')
        .set('Authorization', `Bearer ${elderlyToken}`)
        .send({ assistant_user_id: otherId });

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
    });

    test('缺少参数应返回 400', async () => {
      const res = await request(app)
        .post('/api/remote/request')
        .set('Authorization', `Bearer ${elderlyToken}`)
        .send({});

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
    });
  });

  describe('GET /api/remote/sessions', () => {
    beforeEach(async () => {
      await request(app)
        .post('/api/remote/request')
        .set('Authorization', `Bearer ${elderlyToken}`)
        .send({ assistant_user_id: familyId, request_description: '求助1' });
    });

    test('老人可查看自己的会话列表', async () => {
      const res = await request(app)
        .get('/api/remote/sessions')
        .set('Authorization', `Bearer ${elderlyToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.length).toBeGreaterThan(0);
    });

    test('家人可查看与自己相关的会话列表', async () => {
      const res = await request(app)
        .get('/api/remote/sessions')
        .set('Authorization', `Bearer ${familyToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.length).toBeGreaterThan(0);
    });
  });

  describe('PUT /api/remote/sessions/:id/status', () => {
    let sessionId;

    beforeEach(async () => {
      const reqRes = await request(app)
        .post('/api/remote/request')
        .set('Authorization', `Bearer ${elderlyToken}`)
        .send({ assistant_user_id: familyId, request_description: '状态测试' });
      sessionId = reqRes.body.data.session_id;
    });

    test('应将会话状态更新为 active', async () => {
      const res = await request(app)
        .put(`/api/remote/sessions/${sessionId}/status`)
        .set('Authorization', `Bearer ${familyToken}`)
        .send({ status: 'active' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });

    test('应能完成会话', async () => {
      // 先激活
      await request(app)
        .put(`/api/remote/sessions/${sessionId}/status`)
        .set('Authorization', `Bearer ${familyToken}`)
        .send({ status: 'active' });

      const res = await request(app)
        .put(`/api/remote/sessions/${sessionId}/status`)
        .set('Authorization', `Bearer ${familyToken}`)
        .send({ status: 'completed' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });

    test('无效状态值应返回 400', async () => {
      const res = await request(app)
        .put(`/api/remote/sessions/${sessionId}/status`)
        .set('Authorization', `Bearer ${familyToken}`)
        .send({ status: 'invalid' });

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
    });
  });
});
