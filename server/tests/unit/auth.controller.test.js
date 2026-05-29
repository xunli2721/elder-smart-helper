const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const db = require('../../src/config/db');
const authController = require('../../src/controllers/auth.controller');
const { JWT_SECRET } = require('../../src/middleware/auth');

jest.mock('../../src/config/db');

describe('Auth Controller', () => {
  let req, res;

  beforeEach(() => {
    req = { body: {}, user: {} };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis()
    };
    jest.clearAllMocks();
    jest.spyOn(console, 'error').mockImplementation(() => {});
  });

  afterEach(() => {
    console.error.mockRestore();
  });

  describe('register', () => {
    test('should return 400 when phone is missing', async () => {
      req.body = { password: '123456', name: 'Test', user_type: 'elderly' };

      await authController.register(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith({ success: false, message: '请填写完整信息' });
    });

    test('should return 400 when password is missing', async () => {
      req.body = { phone: '13800138000', name: 'Test', user_type: 'elderly' };

      await authController.register(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
    });

    test('should return 400 when name is missing', async () => {
      req.body = { phone: '13800138000', password: '123456', user_type: 'elderly' };

      await authController.register(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
    });

    test('should return 400 when user_type is missing', async () => {
      req.body = { phone: '13800138000', password: '123456', name: 'Test' };

      await authController.register(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
    });

    test('should return 400 when phone already registered', async () => {
      req.body = { phone: '13800138000', password: '123456', name: 'Test', user_type: 'elderly' };
      db.query.mockResolvedValueOnce([[{ id: 1 }]]);

      await authController.register(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith({ success: false, message: '该手机号已注册' });
    });

    test('should register successfully with valid data', async () => {
      req.body = { phone: '13800138001', password: '123456', name: '张三', user_type: 'elderly' };
      db.query
        .mockResolvedValueOnce([[]]) // no existing user
        .mockResolvedValueOnce([{ insertId: 1 }]); // insert result

      await authController.register(req, res);

      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          data: expect.objectContaining({
            token: expect.any(String),
            user: expect.objectContaining({
              id: 1,
              phone: '13800138001',
              name: '张三',
              user_type: 'elderly'
            })
          })
        })
      );
    });

    test('should return 500 on database error', async () => {
      req.body = { phone: '13800138001', password: '123456', name: 'Test', user_type: 'elderly' };
      db.query.mockRejectedValueOnce(new Error('DB error'));

      await authController.register(req, res);

      expect(res.status).toHaveBeenCalledWith(500);
      expect(res.json).toHaveBeenCalledWith({ success: false, message: '注册失败' });
    });
  });

  describe('login', () => {
    test('should return 400 when phone is missing', async () => {
      req.body = { password: '123456' };

      await authController.login(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith({ success: false, message: '请输入手机号和密码' });
    });

    test('should return 400 when password is missing', async () => {
      req.body = { phone: '13800138000' };

      await authController.login(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
    });

    test('should return 400 when user does not exist', async () => {
      req.body = { phone: '13800138000', password: '123456' };
      db.query.mockResolvedValueOnce([[]]);

      await authController.login(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith({ success: false, message: '用户不存在' });
    });

    test('should return 400 when password is wrong', async () => {
      req.body = { phone: '13800138000', password: 'wrong' };
      const hashedPassword = await bcrypt.hash('123456', 10);
      db.query.mockResolvedValueOnce([[{ id: 1, phone: '13800138000', password: hashedPassword, name: 'Test', user_type: 'elderly', font_size: 'large' }]]);

      await authController.login(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith({ success: false, message: '密码错误' });
    });

    test('should login successfully with correct credentials', async () => {
      req.body = { phone: '13800138000', password: '123456' };
      const hashedPassword = await bcrypt.hash('123456', 10);
      db.query.mockResolvedValueOnce([[{
        id: 1, phone: '13800138000', password: hashedPassword,
        name: '张爷爷', user_type: 'elderly', font_size: 'large'
      }]]);

      await authController.login(req, res);

      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          data: expect.objectContaining({
            token: expect.any(String),
            user: expect.objectContaining({
              id: 1,
              phone: '13800138000',
              name: '张爷爷',
              user_type: 'elderly',
              font_size: 'large'
            })
          })
        })
      );
    });

    test('should return 500 on database error', async () => {
      req.body = { phone: '13800138000', password: '123456' };
      db.query.mockRejectedValueOnce(new Error('DB error'));

      await authController.login(req, res);

      expect(res.status).toHaveBeenCalledWith(500);
    });
  });

  describe('getProfile', () => {
    test('should return user profile', async () => {
      req.user = { id: 1 };
      db.query.mockResolvedValueOnce([[{
        id: 1, phone: '13800138000', name: '张爷爷',
        user_type: 'elderly', font_size: 'large', created_at: '2026-01-01'
      }]]);

      await authController.getProfile(req, res);

      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          data: expect.objectContaining({ id: 1, name: '张爷爷' })
        })
      );
    });

    test('should return 404 when user not found', async () => {
      req.user = { id: 999 };
      db.query.mockResolvedValueOnce([[]]);

      await authController.getProfile(req, res);

      expect(res.status).toHaveBeenCalledWith(404);
      expect(res.json).toHaveBeenCalledWith({ success: false, message: '用户不存在' });
    });

    test('should return 500 on database error', async () => {
      req.user = { id: 1 };
      db.query.mockRejectedValueOnce(new Error('DB error'));

      await authController.getProfile(req, res);

      expect(res.status).toHaveBeenCalledWith(500);
    });
  });
});
