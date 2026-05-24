const request = require('supertest');
const app = require('../../src/index').app;
const db = require('../../src/config/db');

let server;
let elderlyToken, familyToken, adminToken;
let elderlyId, familyId;

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

  // 创建老人用户
  const eRes = await request(app)
    .post('/api/auth/register')
    .send({ phone: '13800001111', password: '123456', name: '张大爷', user_type: 'elderly' });
  elderlyToken = eRes.body.data.token;
  elderlyId = eRes.body.data.user.id;

  // 创建家人用户
  const fRes = await request(app)
    .post('/api/auth/register')
    .send({ phone: '13900001111', password: '123456', name: '张小明', user_type: 'family' });
  familyToken = fRes.body.data.token;
  familyId = fRes.body.data.user.id;

  // 创建管理员
  const aRes = await request(app)
    .post('/api/auth/register')
    .send({ phone: '13700001111', password: '123456', name: '王管理员', user_type: 'admin' });
  adminToken = aRes.body.data.token;
});

describe('User API', () => {
  describe('POST /api/users/bind', () => {
    test('老人可以绑定家人', async () => {
      const res = await request(app)
        .post('/api/users/bind')
        .set('Authorization', `Bearer ${elderlyToken}`)
        .send({ phone: '13900001111', relationship: 'child' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });

    test('家人可以绑定老人', async () => {
      const res = await request(app)
        .post('/api/users/bind')
        .set('Authorization', `Bearer ${familyToken}`)
        .send({ phone: '13800001111', relationship: 'child' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });

    test('不能绑定自己', async () => {
      const res = await request(app)
        .post('/api/users/bind')
        .set('Authorization', `Bearer ${elderlyToken}`)
        .send({ phone: '13800001111', relationship: 'child' });

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
    });

    test('重复绑定应失败', async () => {
      await request(app)
        .post('/api/users/bind')
        .set('Authorization', `Bearer ${elderlyToken}`)
        .send({ phone: '13900001111', relationship: 'child' });

      const res = await request(app)
        .post('/api/users/bind')
        .set('Authorization', `Bearer ${elderlyToken}`)
        .send({ phone: '13900001111', relationship: 'child' });

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
    });

    test('家人只能绑定老人用户', async () => {
      // 再注册一个家人
      const f2Res = await request(app)
        .post('/api/auth/register')
        .send({ phone: '13900002222', password: '123456', name: '李小红', user_type: 'family' });
      const family2Token = f2Res.body.data.token;

      const res = await request(app)
        .post('/api/users/bind')
        .set('Authorization', `Bearer ${familyToken}`)
        .send({ phone: '13900002222', relationship: 'sibling' });

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
    });
  });

  describe('GET /api/users/family', () => {
    beforeEach(async () => {
      await request(app)
        .post('/api/users/bind')
        .set('Authorization', `Bearer ${elderlyToken}`)
        .send({ phone: '13900001111', relationship: 'child' });
    });

    test('老人可以查看已绑定的家人', async () => {
      const res = await request(app)
        .get('/api/users/family')
        .set('Authorization', `Bearer ${elderlyToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.length).toBeGreaterThan(0);
      expect(res.body.data[0].name).toBe('张小明');
    });

    test('家人可以查看已绑定的老人', async () => {
      const res = await request(app)
        .get('/api/users/family')
        .set('Authorization', `Bearer ${familyToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.length).toBeGreaterThan(0);
      expect(res.body.data[0].name).toBe('张大爷');
    });
  });

  describe('DELETE /api/users/family/:id', () => {
    let bindingId;

    beforeEach(async () => {
      await request(app)
        .post('/api/users/bind')
        .set('Authorization', `Bearer ${elderlyToken}`)
        .send({ phone: '13900001111', relationship: 'child' });

      const familyRes = await request(app)
        .get('/api/users/family')
        .set('Authorization', `Bearer ${elderlyToken}`);
      bindingId = familyRes.body.data[0].relationship_id;
    });

    test('应解除绑定', async () => {
      const res = await request(app)
        .delete(`/api/users/family/${bindingId}`)
        .set('Authorization', `Bearer ${elderlyToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });
  });

  describe('PUT /api/users/settings', () => {
    test('应更新用户名', async () => {
      const res = await request(app)
        .put('/api/users/settings')
        .set('Authorization', `Bearer ${elderlyToken}`)
        .send({ name: '新名字' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });

    test('应更新字体大小', async () => {
      const res = await request(app)
        .put('/api/users/settings')
        .set('Authorization', `Bearer ${elderlyToken}`)
        .send({ font_size: 'xlarge' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
    });

    test('无更新内容应返回 400', async () => {
      const res = await request(app)
        .put('/api/users/settings')
        .set('Authorization', `Bearer ${elderlyToken}`)
        .send({});

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
    });
  });

  describe('PUT /api/users/avatar', () => {
    test('应更新头像地址', async () => {
      const res = await request(app)
        .put('/api/users/avatar')
        .set('Authorization', `Bearer ${elderlyToken}`)
        .send({ avatar_url: '/uploads/test-avatar.png' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.avatar_url).toBe('/uploads/test-avatar.png');
    });
  });
});
