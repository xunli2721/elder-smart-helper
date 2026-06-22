const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || '';

function verifyToken(req, res, next) {
  if (!JWT_SECRET) {
    return res.status(500).json({ success: false, message: '服务器配置错误' });
  }

  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ success: false, message: '未登录' });
  }

  const token = authHeader.split(' ')[1];
  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded;
    next();
  } catch (err) {
    return res.status(401).json({ success: false, message: '登录已过期' });
  }
}

module.exports = { verifyToken, JWT_SECRET };