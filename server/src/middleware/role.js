function requireRole(...roles) {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.user_type)) {
      return res.status(403).json({ success: false, message: '权限不足' });
    }
    next();
  };
}

module.exports = { requireRole };