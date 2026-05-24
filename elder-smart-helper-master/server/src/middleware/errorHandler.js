/**
 * 统一错误处理中间件
 */
const logger = require('../utils/logger');

function errorHandler(err, req, res, _next) {
  logger.error(err.message, { stack: err.stack, url: req.originalUrl, method: req.method });

  // JWT 验证错误
  if (err.name === 'JsonWebTokenError') {
    return res.status(401).json({ success: false, message: '无效的登录凭证' });
  }
  if (err.name === 'TokenExpiredError') {
    return res.status(401).json({ success: false, message: '登录已过期' });
  }

  // 请求体过大
  if (err.type === 'entity.too.large') {
    return res.status(413).json({ success: false, message: '请求内容过大' });
  }

  // 数据库错误
  if (err.code && err.code.startsWith('ER_')) {
    return res.status(500).json({ success: false, message: '服务器数据错误' });
  }

  res.status(err.status || 500).json({
    success: false,
    message: err.message || '服务器内部错误'
  });
}

module.exports = errorHandler;
