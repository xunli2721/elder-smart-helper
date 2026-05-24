/**
 * 管理员权限中间件
 */
function requireAdmin(req, res, next) {
  if (req.user && req.user.user_type === 'admin') {
    return next();
  }
  return res.status(403).json({ success: false, message: '需要管理员权限' });
}

module.exports = requireAdmin;
