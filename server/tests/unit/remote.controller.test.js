const db = require('../../src/config/db');
const remoteController = require('../../src/controllers/remote.controller');

jest.mock('../../src/config/db');

describe('Remote Controller', () => {
  let req, res;

  beforeEach(() => {
    req = { body: {}, params: {}, query: {}, user: { id: 1, phone: '13800138000', user_type: 'elderly' } };
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

  describe('requestSession', () => {
    test('should return 400 when assistant_user_id is missing', async () => {
      req.body = {};

      await remoteController.requestSession(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith({ success: false, message: '请选择协助者' });
    });

    test('should return 400 when no family relationship exists', async () => {
      req.body = { assistant_user_id: 2 };
      db.query.mockResolvedValueOnce([[]]);

      await remoteController.requestSession(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith({ success: false, message: '只能向已绑定的家人发起协助' });
    });

    test('should create session successfully', async () => {
      req.body = { assistant_user_id: 2, request_description: '需要帮助' };
      db.query
        .mockResolvedValueOnce([[{ id: 1 }]]) // relationship exists
        .mockResolvedValueOnce([{ insertId: 10 }]); // insert

      await remoteController.requestSession(req, res);

      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: true, data: { session_id: 10 } })
      );
    });

    test('should use empty description when not provided', async () => {
      req.body = { assistant_user_id: 2 };
      db.query
        .mockResolvedValueOnce([[{ id: 1 }]])
        .mockResolvedValueOnce([{ insertId: 11 }]);

      await remoteController.requestSession(req, res);

      expect(db.query).toHaveBeenCalledWith(
        expect.any(String),
        expect.arrayContaining([1, 2, 'requested', ''])
      );
    });
  });

  describe('getSessions', () => {
    test('should return sessions for elderly user', async () => {
      db.query.mockResolvedValueOnce([[
        { id: 1, status: 'requested', assistant_name: '小张' }
      ]]);

      await remoteController.getSessions(req, res);

      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          data: expect.arrayContaining([
            expect.objectContaining({ assistant_name: '小张' })
          ])
        })
      );
    });

    test('should return sessions for family user', async () => {
      req.user.user_type = 'family';
      db.query.mockResolvedValueOnce([[
        { id: 1, status: 'active', elderly_name: '张爷爷' }
      ]]);

      await remoteController.getSessions(req, res);

      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: true })
      );
    });

    test('should return paginated sessions when page/pageSize provided', async () => {
      req.query = { page: '1', pageSize: '10' };
      db.query
        .mockResolvedValueOnce([[{ total: 1 }]]) // count query
        .mockResolvedValueOnce([[{ id: 1, status: 'requested', assistant_name: '小张' }]]); // data query

      await remoteController.getSessions(req, res);

      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          data: expect.any(Array),
          pagination: expect.objectContaining({
            page: 1,
            pageSize: 10,
            total: 1,
            totalPages: 1,
          }),
        })
      );
    });
  });

  describe('updateStatus', () => {
    test('should return 400 for invalid status', async () => {
      req.params.id = '1';
      req.body = { status: 'invalid' };

      await remoteController.updateStatus(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith({ success: false, message: '无效的状态' });
    });

    test('should update status to active', async () => {
      req.params.id = '1';
      req.body = { status: 'active' };
      db.query
        .mockResolvedValueOnce([{ affectedRows: 1 }])  // update
        .mockResolvedValueOnce([[{ elderly_user_id: 1, assistant_user_id: 2 }]]);  // get session for notification

      await remoteController.updateStatus(req, res);

      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: true, message: '状态更新成功' })
      );
    });

    test('should update status to completed', async () => {
      req.params.id = '1';
      req.body = { status: 'completed' };
      db.query
        .mockResolvedValueOnce([{ affectedRows: 1 }])
        .mockResolvedValueOnce([[{ elderly_user_id: 1, assistant_user_id: 2 }]]);

      await remoteController.updateStatus(req, res);

      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: true })
      );
    });

    test('should update status to cancelled', async () => {
      req.params.id = '1';
      req.body = { status: 'cancelled' };
      db.query
        .mockResolvedValueOnce([{ affectedRows: 1 }])
        .mockResolvedValueOnce([[{ elderly_user_id: 1, assistant_user_id: 2 }]]);

      await remoteController.updateStatus(req, res);

      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: true })
      );
    });

    test('should return 404 when session not found', async () => {
      req.params.id = '999';
      req.body = { status: 'active' };
      db.query.mockResolvedValueOnce([{ affectedRows: 0 }]);

      await remoteController.updateStatus(req, res);

      expect(res.status).toHaveBeenCalledWith(404);
      expect(res.json).toHaveBeenCalledWith({ success: false, message: '会话不存在' });
    });
  });
});