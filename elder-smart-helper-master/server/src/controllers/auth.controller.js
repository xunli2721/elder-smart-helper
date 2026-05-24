const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const db = require('../config/db');
const { JWT_SECRET } = require('../middleware/auth');

// 注册
exports.register = async (req, res) => {
  try {
    const { phone, password, name, user_type } = req.body;
    if (!phone || !password || !name || !user_type) {
      return res.status(400).json({ success: false, message: '请填写完整信息' });
    }

    const [existing] = await db.query('SELECT id FROM users WHERE phone = ?', [phone]);
    if (existing.length > 0) {
      return res.status(400).json({ success: false, message: '该手机号已注册' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const [result] = await db.query(
      'INSERT INTO users (phone, password, name, user_type) VALUES (?, ?, ?, ?)',
      [phone, hashedPassword, name, user_type]
    );

    const token = jwt.sign({ id: result.insertId, phone, user_type }, JWT_SECRET, { expiresIn: '7d' });
    res.json({ success: true, data: { token, user: { id: result.insertId, phone, name, user_type } } });
  } catch (err) {
    console.error('Register error:', err);
    res.status(500).json({ success: false, message: '注册失败' });
  }
};

// 登录
exports.login = async (req, res) => {
  try {
    const { phone, password } = req.body;
    if (!phone || !password) {
      return res.status(400).json({ success: false, message: '请输入手机号和密码' });
    }

    const [users] = await db.query('SELECT * FROM users WHERE phone = ?', [phone]);
    if (users.length === 0) {
      return res.status(400).json({ success: false, message: '用户不存在' });
    }

    const user = users[0];
    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(400).json({ success: false, message: '密码错误' });
    }

    const token = jwt.sign({ id: user.id, phone: user.phone, user_type: user.user_type }, JWT_SECRET, { expiresIn: '7d' });
    res.json({
      success: true,
      data: {
        token,
        user: { id: user.id, phone: user.phone, name: user.name, user_type: user.user_type, font_size: user.font_size }
      }
    });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ success: false, message: '登录失败' });
  }
};

// 获取当前用户信息
exports.getProfile = async (req, res) => {
  try {
    const [users] = await db.query('SELECT id, phone, name, user_type, avatar_url, font_size, language_preference, created_at FROM users WHERE id = ?', [req.user.id]);
    if (users.length === 0) {
      return res.status(404).json({ success: false, message: '用户不存在' });
    }
    res.json({ success: true, data: users[0] });
  } catch (err) {
    console.error('GetProfile error:', err);
    res.status(500).json({ success: false, message: '获取信息失败' });
  }
};

// 修改密码
exports.changePassword = async (req, res) => {
  try {
    const { old_password, new_password } = req.body;

    const [users] = await db.query('SELECT password FROM users WHERE id = ?', [req.user.id]);
    if (users.length === 0) {
      return res.status(404).json({ success: false, message: '用户不存在' });
    }

    const isMatch = await bcrypt.compare(old_password, users[0].password);
    if (!isMatch) {
      return res.status(400).json({ success: false, message: '旧密码不正确' });
    }

    const hashedPassword = await bcrypt.hash(new_password, 10);
    await db.query('UPDATE users SET password = ? WHERE id = ?', [hashedPassword, req.user.id]);

    res.json({ success: true, message: '密码修改成功' });
  } catch (err) {
    console.error('ChangePassword error:', err);
    res.status(500).json({ success: false, message: '密码修改失败' });
  }
};

// 刷新 Token
exports.refreshToken = async (req, res) => {
  try {
    const refreshSecret = process.env.JWT_REFRESH_SECRET || 'default_refresh_secret';
    const token = jwt.sign(
      { id: req.user.id, phone: req.user.phone, user_type: req.user.user_type },
      refreshSecret,
      { expiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '30d' }
    );
    res.json({ success: true, data: { token } });
  } catch (err) {
    console.error('RefreshToken error:', err);
    res.status(500).json({ success: false, message: '刷新Token失败' });
  }
};
