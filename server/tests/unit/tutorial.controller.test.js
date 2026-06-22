const db = require('../../src/config/db');
const tutorialController = require('../../src/controllers/tutorial.controller');

jest.mock('../../src/config/db');

describe('Tutorial Controller', () => {
  let req, res;

  beforeEach(() => {
    req = { body: {}, params: {}, query: {} };
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

  describe('getAll', () => {
    test('should return all active tutorials', async () => {
      const mockTutorials = [
        { id: 1, title: '打电话', category: 'basic', steps: '[{"step":1,"title":"步骤1","description":"desc"}]' },
        { id: 2, title: '微信', category: 'communication', steps: '[{"step":1,"title":"步骤1","description":"desc"}]' }
      ];
      db.query.mockResolvedValueOnce([mockTutorials]);

      await tutorialController.getAll(req, res);

      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          data: expect.arrayContaining([
            expect.objectContaining({ id: 1, title: '打电话' })
          ])
        })
      );
    });

    test('should filter by category when provided', async () => {
      req.query.category = 'basic';
      db.query.mockResolvedValueOnce([[{ id: 1, title: '打电话', category: 'basic', steps: '[]' }]]);

      await tutorialController.getAll(req, res);

      expect(db.query).toHaveBeenCalledWith(
        expect.stringContaining('category = ?'),
        expect.arrayContaining(['basic'])
      );
    });

    test('should parse steps JSON string', async () => {
      db.query.mockResolvedValueOnce([[
        { id: 1, title: 'Test', steps: '[{"step":1,"title":"s1","description":"d1"}]' }
      ]]);

      await tutorialController.getAll(req, res);

      const result = res.json.mock.calls[0][0];
      expect(Array.isArray(result.data[0].steps)).toBe(true);
    });

    test('should return 500 on database error', async () => {
      db.query.mockRejectedValueOnce(new Error('DB error'));

      await tutorialController.getAll(req, res);

      expect(res.status).toHaveBeenCalledWith(500);
    });
  });

  describe('getById', () => {
    test('should return tutorial by id', async () => {
      req.params.id = '1';
      db.query.mockResolvedValueOnce([[{
        id: 1, title: '打电话', category: 'basic',
        steps: '[{"step":1,"title":"步骤1","description":"拨号"}]'
      }]]);

      await tutorialController.getById(req, res);

      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          data: expect.objectContaining({ id: 1, title: '打电话' })
        })
      );
    });

    test('should return 404 when tutorial not found', async () => {
      req.params.id = '999';
      db.query.mockResolvedValueOnce([[]]);

      await tutorialController.getById(req, res);

      expect(res.status).toHaveBeenCalledWith(404);
      expect(res.json).toHaveBeenCalledWith({ success: false, message: '教程不存在' });
    });
  });

  describe('create', () => {
    test('should return 400 when title is missing', async () => {
      req.body = { category: 'basic', steps: [{ step: 1 }] };

      await tutorialController.create(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
    });

    test('should return 400 when category is missing', async () => {
      req.body = { title: 'Test', steps: [{ step: 1 }] };

      await tutorialController.create(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
    });

    test('should return 400 when steps is missing', async () => {
      req.body = { title: 'Test', category: 'basic' };

      await tutorialController.create(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
    });

    test('should create tutorial successfully', async () => {
      req.body = {
        title: '新教程',
        description: '描述',
        category: 'basic',
        difficulty_level: 'beginner',
        steps: [{ step: 1, title: '步骤1', description: '说明' }]
      };
      db.query.mockResolvedValueOnce([{ insertId: 5 }]);

      await tutorialController.create(req, res);

      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: true, data: { id: 5 } })
      );
    });
  });

  describe('update', () => {
    test('should update tutorial successfully', async () => {
      req.params.id = '1';
      req.body = {
        title: '更新标题', description: 'desc', category: 'basic',
        difficulty_level: 'beginner', image_url: '', steps: [{ step: 1 }]
      };
      db.query.mockResolvedValueOnce([{ affectedRows: 1 }]);

      await tutorialController.update(req, res);

      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: true, message: '更新成功' })
      );
    });

    test('should return 404 when tutorial not found', async () => {
      req.params.id = '999';
      req.body = { title: 'x', description: '', category: 'basic', difficulty_level: 'beginner', image_url: '', steps: [] };
      db.query.mockResolvedValueOnce([{ affectedRows: 0 }]);

      await tutorialController.update(req, res);

      expect(res.status).toHaveBeenCalledWith(404);
    });
  });

  describe('remove', () => {
    test('should delete tutorial successfully', async () => {
      req.params.id = '1';
      db.query.mockResolvedValueOnce([{ affectedRows: 1 }]);

      await tutorialController.remove(req, res);

      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: true, message: '删除成功' })
      );
    });

    test('should return 404 when tutorial not found', async () => {
      req.params.id = '999';
      db.query.mockResolvedValueOnce([{ affectedRows: 0 }]);

      await tutorialController.remove(req, res);

      expect(res.status).toHaveBeenCalledWith(404);
    });
  });
});
