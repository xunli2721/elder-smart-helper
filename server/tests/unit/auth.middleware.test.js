const jwt = require('jsonwebtoken');
const { verifyToken, JWT_SECRET } = require('../../src/middleware/auth');

describe('Auth Middleware - verifyToken', () => {
  let req, res, next;

  beforeEach(() => {
    req = { headers: {} };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis()
    };
    next = jest.fn();
  });

  test('should return 401 when no authorization header', () => {
    verifyToken(req, res, next);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith({ success: false, message: '未登录' });
    expect(next).not.toHaveBeenCalled();
  });

  test('should return 401 when authorization header has no Bearer prefix', () => {
    req.headers.authorization = 'Token abc123';

    verifyToken(req, res, next);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith({ success: false, message: '未登录' });
    expect(next).not.toHaveBeenCalled();
  });

  test('should return 401 when token is expired', () => {
    const expiredToken = jwt.sign(
      { id: 1, phone: '13800138000', user_type: 'elderly' },
      JWT_SECRET,
      { expiresIn: '0s' }
    );
    req.headers.authorization = `Bearer ${expiredToken}`;

    verifyToken(req, res, next);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith({ success: false, message: '登录已过期' });
    expect(next).not.toHaveBeenCalled();
  });

  test('should return 401 when token is invalid', () => {
    req.headers.authorization = 'Bearer invalid.token.here';

    verifyToken(req, res, next);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith({ success: false, message: '登录已过期' });
    expect(next).not.toHaveBeenCalled();
  });

  test('should call next and set req.user when token is valid', () => {
    const payload = { id: 1, phone: '13800138000', user_type: 'elderly' };
    const token = jwt.sign(payload, JWT_SECRET, { expiresIn: '7d' });
    req.headers.authorization = `Bearer ${token}`;

    verifyToken(req, res, next);

    expect(next).toHaveBeenCalled();
    expect(req.user).toBeDefined();
    expect(req.user.id).toBe(1);
    expect(req.user.phone).toBe('13800138000');
    expect(req.user.user_type).toBe('elderly');
  });

  test('should export JWT_SECRET', () => {
    expect(JWT_SECRET).toBeDefined();
    expect(typeof JWT_SECRET).toBe('string');
  });
});
