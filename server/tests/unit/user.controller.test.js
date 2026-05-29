const db = require('../../src/config/db');
const userController = require('../../src/controllers/user.controller');

jest.mock('../../src/config/db');

describe('User Controller', () => {
  let req, res;

  beforeEach(() => {
    req = { body: {}, params: {}, user: { id: 1, phone: '13800138000', user_type: 'elderly' } };
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

  describe('bindFamily', () => {
    test('should return 400 when phone is missing', async () => {
      req.body = {};

      await userController.bindFamily(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith({ success: false, message: '请输入家人手机号' });
    });

    test('should return 404 when family user not found', async () => {
      req.body = { phone: '13900000000' };
      db.query.mockResolvedValueOnce([[]]);

      await userController.bindFamily(req, res);

      expect(res.status).toHaveBeenCalledWith(404);
      expect(res.json).toHaveBeenCalledWith({ success: false, message: '未找到该用户' });
    });

    test('should return 400 when trying to bind self', async () => {
      req.body = { phone: '13800138000' };
      db.query.mockResolvedValueOnce([[{ id: 1, name: '自己', user_type: 'elderly' }]]);

      await userController.bindFamily(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith({ success: false, message: '不能绑定自己' });
    });

    test('should return 400 when family user tries to bind non-elderly', async () => {
      req.user.user_type = 'family';
      req.body = { phone: '13900000000' };
      db.query.mockResolvedValueOnce([[{ id: 2, name: '小王', user_type: 'family' }]]);

      await userController.bindFamily(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith({ success: false, message: '只能绑定老人用户' });
    });

    test('should return 400 when admin tries to bind', async () => {
      req.user.user_type = 'admin';
      req.body = { phone: '13900000000' };
      db.query.mockResolvedValueOnce([[{ id: 2, name: '小王', user_type: 'family' }]]);

      await userController.bindFamily(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith({ success: false, message: '管理员不支持绑定' });
    });

    test('should return 400 when already bound', async () => {
      req.body = { phone: '13900000000' };
      db.query
        .mockResolvedValueOnce([[{ id: 2, name: '小张', user_type: 'family' }]])
        .mockResolvedValueOnce([[{ id: 1 }]]); // existing relationship

      await userController.bindFamily(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith({ success: false, message: '已经绑定过了' });
    });

    test('should bind family successfully', async () => {
      req.body = { phone: '13900000000', relationship: 'child' };
      db.query
        .mockResolvedValueOnce([[{ id: 2, name: '小张', user_type: 'family' }]])
        .mockResolvedValueOnce([[]]) // no existing
        .mockResolvedValueOnce([{ insertId: 1 }]);

      await userController.bindFamily(req, res);

      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: true, message: '绑定成功' })
      );
    });
  });

  describe('getFamily', () => {
    test('should return family list for elderly user', async () => {
      db.query.mockResolvedValueOnce([[
        { id: 2, name: '小张', phone: '13900000000', user_type: 'family', relationship: 'child' }
      ]]);

      await userController.getFamily(req, res);

      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          data: expect.arrayContaining([
            expect.objectContaining({ id: 2, name: '小张' })
          ])
        })
      );
    });

    test('should return family list for family user', async () => {
      req.user.user_type = 'family';
      db.query.mockResolvedValueOnce([[
        { id: 1, name: '张爷爷', phone: '13800138000', user_type: 'elderly', relationship: 'child' }
      ]]);

      await userController.getFamily(req, res);

      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: true })
      );
    });
  });

  describe('unbindFamily', () => {
    test('should unbind successfully', async () => {
      req.params.id = '1';
      db.query.mockResolvedValueOnce([{ affectedRows: 1 }]);

      await userController.unbindFamily(req, res);

      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: true, message: '解除绑定成功' })
      );
    });

    test('should return 404 when relationship not found', async () => {
      req.params.id = '999';
      db.query.mockResolvedValueOnce([{ affectedRows: 0 }]);

      await userController.unbindFamily(req, res);

      expect(res.status).toHaveBeenCalledWith(404);
    });
  });

  describe('updateSettings', () => {
    test('should return 400 when no fields provided', async () => {
      req.body = {};

      await userController.updateSettings(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith({ success: false, message: '没有要更新的内容' });
    });

    test('should update name successfully', async () => {
      req.body = { name: '新名字' };
      db.query.mockResolvedValueOnce([{ affectedRows: 1 }]);

      await userController.updateSettings(req, res);

      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: true, message: '更新成功' })
      );
    });

    test('should update font_size successfully', async () => {
      req.body = { font_size: 'xlarge' };
      db.query.mockResolvedValueOnce([{ affectedRows: 1 }]);

      await userController.updateSettings(req, res);

      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: true, message: '更新成功' })
      );
    });

    test('should update both name and font_size', async () => {
      req.body = { name: '新名字', font_size: 'small' };
      db.query.mockResolvedValueOnce([{ affectedRows: 1 }]);

      await userController.updateSettings(req, res);

      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: true })
      );
    });
  });
});
